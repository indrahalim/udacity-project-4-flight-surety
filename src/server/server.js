import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let oracles = [];

// Status codes
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

const ORACLES_COUNT = 20;
const FIRST_ORACLE_ACCOUNT_IDX = 40; // to make sure account used to register oracle has sufficient gas

const gas = 5000000;
const gasPrice = 100000000000;

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
}, function (error, event) {
    if (error) console.log(error);
    console.log(event);
});

let flightStatus = STATUS_CODE_LATE_AIRLINE; // Status for testing purpose

web3.eth.getAccounts().then(accounts => {
    // Initialize oracles addresses and indexes with smart contract
    flightSuretyApp.methods.REGISTRATION_FEE().call({
        "from": accounts[0],
    }).then(fee => {
        // Register oracle starting from certain index
        for (let i = 1; i < ORACLES_COUNT; i++) {
            let account = accounts[i + FIRST_ORACLE_ACCOUNT_IDX];
            oracles.push(account);

            flightSuretyApp.methods.registerOracle().send({
                "from": account,
                "value": fee,
                "gas": gas,
                "gasPrice": gasPrice
            }).then(result => {
                console.log('Registered oracle at address: ' + account);
            }).catch(err => {
                // oracle errored
                console.log('Could not register oracle at address: ' + account + ', with error: ' + err);
            })
        }

        oracles.forEach(oracle => {
            flightSuretyApp.methods.getMyIndexes().call({
                "from": oracle,
                "gas": gas,
                "gasPrice": gasPrice
            }).then(result => {
                console.log('Assigned indexes: ' + result[0] + ', ' + result[1] + ', ' + result[2] + '\tfor oracle: ' + oracle);
            }).catch(error => {
                console.log('Could not retrieve oracle indexes: ' + error);
            })
        });
        console.log('Oracles are registered');

        // start Listen for OracleRequest event
        flightSuretyApp.events.OracleRequest({fromBlock: 'latest'},
            function (error, event) {
                if (error) console.log(error);
                let eventData = event['returnValues'];
                console.log(eventResult);

                let index = eventData['index'];
                let airline = eventData['airline'];
                let flight = eventData['flight'];
                let timestamp = eventData['timestamp'];
                console.log('Only oracle with index ' + index + ' should respond to the request.');

                // Query the oracles with matching index for the flight status
                oracles.forEach(oracle => {
                    flightSuretyApp.methods.getMyIndexes().call({
                        "from": oracle,
                        "gas": gas,
                        "gasPrice": gasPrice
                    }).then(res => {
                        if (res[0] == index || res[1] == index || res[2] == index) {
                            flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, flightStatus).send({
                                "from": oracle,
                                "gas": gas,
                                "gasPrice": gasPrice
                            }).then(result => {
                                console.log('Oracle [' + oracle + '] response submitted successfully.')
                            }).catch(error => {
                                console.log('Could not submit oracle response due to: ' + error)
                            });
                        }

                    }).catch(error => {
                        console.log('Could not retrieve oracle index due to: ' + error);
                    })
                });
            });
    }).catch(err => {
        console.log('Could not read registration fee. ' + err)
    });
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
        message: 'An API for use with your Dapp!'
    })
})

export default app;


