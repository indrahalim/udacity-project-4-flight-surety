var Test = require("../config/testConfig.js");
var BigNumber = require("bignumber.js");
var Web3 = require("web3");

contract("Flight Surety Tests", async (accounts) => {
  var config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    await config.flightSuretyData.authorizeCaller( config.flightSuretyApp.address, {from: config.owner });

    await config.flightSuretyApp.registerAirline(config.firstAirline, {from: config.owner}); // TODO remove this hacky method
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(settings) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyApp.isOperational();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(settings) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyApp.setOperatingStatus(false, {
        from: config.testAddresses[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(settings) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyApp.setOperatingStatus(false, {from: config.owner});
    } catch (e) {
      accessDenied = true;
    }

    assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
  });

  it(`(settings) can prevent unecessary operating status change`, async function () {
    let currentStatus = await config.flightSuretyApp.isOperational();

    let errorThrown = false;
    try {
      errorThrown = await config.flightSuretyApp.setOperatingStatus(
        currentStatus,
        { from: config.testAddresses[0] }
      );
    } catch (e) {
      errorThrown = true;
    }

    assert.equal( errorThrown, true, "Should throw error if operational status == mode");
  });

  it(`(settings) can block access to functions using requireIsOperational when operating status is false`, async function () {
    let currentStatus = await config.flightSuretyApp.isOperational();
    if (currentStatus) {
      await config.flightSuretyData.setOperatingStatus(false);
    }

    let reverted = false;
    try {
      await config.flightSuretyApp.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyApp.setOperatingStatus(true);
  });

  it("(airline) first airline is registered when contract is deployed", async () => {
    let result = await config.flightSuretyApp.isRegisteredAirline(config.firstAirline);

    assert.equal( result, true, "contract owner should be registered as first airline");
  });

  it("(airline) unregistered airline cannot register new airline", async () => {
    let result = false;

    try {
      result = await config.flightSuretyApp.registerAirline(config.fourthAirline, { from: config.thirdAirline });
    } catch {
      result = false;
    }

    assert.equal(result, false, "unregistered airline should not be able to register new airline");
  });

  it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ACT
    try {
      await config.flightSuretyApp.registerAirline(config.secondAirline, { from: config.firstAirline});
    } catch (e) {
      console.log("error flightSuretyApp.registerAirline: " + e);
    }

    let result = await config.flightSuretyApp.isRegisteredAirline(config.secondAirline);

    // ASSERT
    assert.equal( result, false, "Airline should not be able to register another airline if it hasn't provided funding");
  });

  it("(airline) can only register an Airline using registerAirline() if it has provided funding", async () => {
    let amountInWei = new Web3.utils.BN(Web3.utils.toWei("10", "ether"));
    await config.flightSuretyApp.fundAirline({ from: config.firstAirline, value: amountInWei});

    try {
       await config.flightSuretyApp.registerAirline(config.secondAirline, {from: config.firstAirline});
    } catch (e) {
       console.log("error flightSuretyApp.registerAirline: " + e);
    }

    let isRegistered = await config.flightSuretyApp.isRegisteredAirline(config.secondAirline);

    // ASSERT
    assert.equal(isRegistered, true, "Airline should be able to register another airline if it has provided funding");
  });

  it('(airline) Only existing airline may register a new airline until there are at least four airlines registered', async () => {
    // 2nd airline provides fund
    let amountInWei = new Web3.utils.BN(Web3.utils.toWei("10", "ether"));
    await config.flightSuretyApp.fundAirline({from: config.secondAirline, value: amountInWei});

    // 2nd airline can register 3rd airline
    await config.flightSuretyApp.registerAirline(config.thirdAirline, {from: config.secondAirline});
    let result = await config.flightSuretyApp.isRegisteredAirline(config.thirdAirline);
    assert.equal(result, true, "Second airline can register a new airline");

    // 3nd airline provides fund
    await config.flightSuretyApp.fundAirline({from: config.thirdAirline, value: amountInWei});

    // 3nd airline can register 4th airline
    await config.flightSuretyApp.registerAirline(config.fourthAirline, {from: config.thirdAirline});
    result = await config.flightSuretyApp.isRegisteredAirline(config.fourthAirline);
    assert.equal(result, true, "Third airline can register a new airline");

  });

  it('(airline) Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines', async() => {
    let amountInWei = new Web3.utils.BN(Web3.utils.toWei("10", "ether"));

    // 4th airline provides fund
    await config.flightSuretyApp.fundAirline({from: config.fourthAirline, value: amountInWei});

    // 4th airline registers 5th airline, but status is still pending
    await config.flightSuretyApp.registerAirline(config.fifthAirline, {from: config.fourthAirline});
    let result = await config.flightSuretyApp.isRegisteredAirline(config.fifthAirline);
    assert.equal(result, false, "Fifth Airline status is still pending");

    // Need vote from other members
    await config.flightSuretyApp.voteAirline(config.fifthAirline, {from: config.firstAirline});
    result = await config.flightSuretyApp.isRegisteredAirline(config.fifthAirline);
    assert.equal(result, false, "Fifth airline should now be registered");
  });

  //   it('(airline) Airline can be registered, but does not participate in contract until it submits funding of 10 ether (make sure it is not 10 wei)', async() => {

  //   });
});
