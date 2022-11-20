
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var Web3 = require('web3');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);

    config.flightSuretyApp.registerAirline(config.firstAirline, {from: config.owner});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(settings) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(settings) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(settings) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(settings) can prevent unecessary operating status change`, async function () {

      let currentStatus = await config.flightSuretyData.isOperational();

      let errorThrown = false;
      try 
      {
          errorThrown = await config.flightSuretyData.setOperatingStatus(currentStatus, {from: config.testAddresses[0]});
      }
      catch(e) {
          errorThrown = true;
      }
      assert.equal(errorThrown, true, "Should throw error if operational status == mode");

  });

  it(`(settings) can block access to functions using requireIsOperational when operating status is false`, async function () {

      let currentStatus = await config.flightSuretyData.isOperational();
      if (currentStatus) {
        await config.flightSuretyData.setOperatingStatus(false);
      }

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) first airline is registered when contract is deployed', async () => {
    let result = await config.flightSuretyApp.isRegisteredAirline.call(config.firstAirline);

    assert.equal(result, true, "contract owner should be registered as first airline");
  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    // TODO revisit this when all tests are done
    
    // ARRANGE
    let newAirline = accounts[2];
    let result = false;

    // ACT
    try {
        await config.flightSuretyApp.registerAirline.call(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        console.log("error flightSuretyApp.registerAirline: " + e);
    }

    try {
        result = await config.flightSuretyData.isAirline.call(newAirline); 
    } catch (e) {
        console.log("error flightSuretyData.isAirline: " + e);
    }


    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) Only existing airline may register a new airline until there are at least four airlines registered', async () => {

  });
 

});
