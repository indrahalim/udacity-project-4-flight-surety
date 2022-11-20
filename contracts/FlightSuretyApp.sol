// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

// import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.2/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Account used to deploy contract
    address public contractOwner;

    uint8 private constant MIN_AIRLINE_FOR_CONSENSUS = 4;
    uint8 private constant REGISTRATION_CONSENSUS_THRESHOLD = 50;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    address payable fsDataAddress;
    FlightSuretyDataAbstract flightSuretyData;
    uint256 public constant MINIMUM_AIRLINE_FUND_NEEDED = 10 ether;

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address payable dataAddress) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyDataAbstract(dataAddress);
        fsDataAddress= dataAddress;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        // Modify to call data contract's status
        require(
            flightSuretyData.isOperational(),
            "Contract is currently not operational"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireRegisteredAirline() {
        require(flightSuretyData.isRegisteredAirline(msg.sender), "Only airline that has been registered is allowed");
        _;
    }

    modifier requireFundedAirline() {
        if (flightSuretyData.getTotalRegisteredAirline() > 0) {
            require(flightSuretyData.isFundedAirline(msg.sender), "Only airline that has provided funding is allowed");
        } else {
            require(contractOwner == msg.sender, "You're not an contract owner");
        }
        _;
    }

    /********************************************************************************************/
    /*                                          EVENTS                                          */
    /********************************************************************************************/
    event AirlineNominated(address indexed airlineAddress);
    event AirlineFunded(address indexed airlineAddress, uint256 funds);
    event AirlineRegistered(address indexed airlineAddress);

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    function setOperatingStatus(bool mode) public requireContractOwner {
        flightSuretyData.setOperatingStatus(mode);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address airline)
        public
        requireFundedAirline
        returns (bool)
    {
        // Get number of registered airline
        // If total registered airline > threshold, do consensus
        uint256 totalRegisteredAirlines = flightSuretyData .getTotalRegisteredAirline();

        if (totalRegisteredAirlines >= MIN_AIRLINE_FOR_CONSENSUS) {
            uint256 voteNeeded = totalRegisteredAirlines.div(
                REGISTRATION_CONSENSUS_THRESHOLD
            );
            if (flightSuretyData.nominateAirline(airline, voteNeeded)) {
                return flightSuretyData.voteAirline(airline);
            }
            return false;
        }

        return flightSuretyData.registerAirline(airline);
    }

    function isRegisteredAirline(address airline)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return flightSuretyData.isRegisteredAirline(airline);
    }

    function fundAirline()
        public
        payable
        requireIsOperational
        requireRegisteredAirline
        returns (bool, uint256)
    {
        require(msg.value >= MINIMUM_AIRLINE_FUND_NEEDED, "funding requires 10 Ether");

        fsDataAddress.transfer(msg.value);
        (bool result, uint256 funds) = flightSuretyData.fundAirline(msg.sender, msg.value);
        emit AirlineFunded(msg.sender, msg.value);

        return (result, funds);
    }

    function isFundedAirline(address airline)
        public
        view
        requireIsOperational
        returns (bool)
    {
        return flightSuretyData.isFundedAirline(airline);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight() external pure {}

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal pure {}

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account)
        internal
        returns (uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}

interface FlightSuretyDataAbstract {
    function isOperational() external view returns (bool);

    function isAirline() external view returns (bool);

    function setOperatingStatus(bool mode) external;

    function authorizeCaller(address airline) external;

    function revokeAuthorizeCaller(address airline) external;

    function isRegisteredAirline(address airline) external view returns (bool);

    function isFundedAirline(address airline) external view returns (bool);

    function registerAirline(address airline) external returns (bool success);

    function getTotalRegisteredAirline() external returns (uint256);

    function nominateAirline(address airline, uint256 voteNeeded)
        external
        returns (bool);

    function voteAirline(address airline) external returns (bool success);

    function fundAirline(address airline, uint256 amount) external returns (bool success, uint256 funds);

    function buy() external payable;

    function creditInsurees() external pure;

    function pay() external pure;
}
