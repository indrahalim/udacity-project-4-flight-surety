// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

// import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../contracts/FlightSuretyApp.sol";

contract FlightSuretyData is FlightSuretyDataAbstract {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    mapping(address => bool) private authorizedCaller;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
        authorizedCaller[contractOwner] = true;
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
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedCaller() {
        require(
            authorizedCaller[msg.sender] == true,
            "Caller is not authorized"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() external view override returns (bool) {
        return operational;
    }

    function isAirline()
        external
        view
        override
        requireIsOperational
        returns (bool)
    {
        return true; // TODO change this implementation
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode)
        external
        override
        requireContractOwner
    {
        require(mode != operational, "Operational mode is already applied");
        operational = mode;
    }

    function authorizeCaller(address _address)
        external
        override
        requireIsOperational
        requireContractOwner
    {
        authorizedCaller[_address] = true;
    }

    function revokeAuthorizeCaller(address _address)
        external
        override
        requireIsOperational
        requireContractOwner
    {
        delete authorizedCaller[_address];
    }

    function isAuthorizedCaller(address _address) external override view requireIsOperational returns (bool){
        return authorizedCaller[_address];
    }

    /********************************************************************************************/
    /*                                      SMART CONTRACT VARIABLES                            */
    /********************************************************************************************/
    enum AirlineStatus { Unregistered, Nominated, Registered, Funded }
    struct Airline {
        AirlineStatus status;
        uint256 funds;
        uint256 voteNeeded;
        uint256 totalVote;
    }
    mapping(address => Airline) private airlines;
    mapping(address => Airline) private nominatedAirlines;
    uint256 private totalRegisteredAirlines = 0;
    uint256 private totalNominatedAirlines = 0;
    uint256 private totalFundedAirlines = 0;

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function isRegisteredAirline(address airline) external override requireIsOperational returns (bool) {
        return airlines[airline].status == AirlineStatus.Registered;
    }

    function isFundedAirline(address airline) external override requireIsOperational returns (bool) {
        return airlines[airline].status == AirlineStatus.Funded;
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address airline)
        external
        override
        requireIsOperational
        requireAuthorizedCaller
        returns (bool success, uint256 votes)
    {
        if (airlines[airline].status == AirlineStatus.Registered) {
            return (false, 0);
        }

        uint256 totalVote = 1;
        airlines[airline] = Airline({
            status: AirlineStatus.Registered,
            funds: 0,
            voteNeeded: 0,
            totalVote: totalVote
        });
        totalRegisteredAirlines += 1;
        return (true, totalVote);
    }

    function getTotalRegisteredAirline() external override returns (uint256) {
        return totalRegisteredAirlines;
    }

    function nominateAirline(address airline, uint256 voteNeeded)
        external
        override
        requireIsOperational
        requireAuthorizedCaller
        returns (bool)
    {
        if (
            nominatedAirlines[airline].status == AirlineStatus.Nominated
        ) {
            return false;
        }

        nominatedAirlines[airline] = Airline({
            status: AirlineStatus.Nominated,
            funds: 0,
            voteNeeded: voteNeeded,
            totalVote: 0
        });
        totalNominatedAirlines += 1;

        return true;
    }

    function voteAirline(address airline) external override returns (bool success, uint256 votes) {
        if (
            nominatedAirlines[airline].status == AirlineStatus.Nominated
        ) {
            return (false, nominatedAirlines[airline].totalVote);
        }

        nominatedAirlines[airline].totalVote += 1;

        if (nominatedAirlines[airline].totalVote >= nominatedAirlines[airline].voteNeeded) {
            // TODO create and emit AirlineRegistered

            airlines[airline] = nominatedAirlines[airline];
            airlines[airline].status = AirlineStatus.Registered;

            delete(nominatedAirlines[airline]);
        }
        
        return (true, nominatedAirlines[airline].totalVote);
    }

    function fundAirline(address airline, uint256 amount) external override returns (bool, uint256) {
        airlines[airline].funds = airlines[airline].funds.add(amount);
        airlines[airline].status = AirlineStatus.Funded;
        totalFundedAirlines++;

        return (true, airlines[airline].funds);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy() external payable override {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure override {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure override {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {
        fund();
    }

    receive() external payable {
        // custom function code
    }
}
