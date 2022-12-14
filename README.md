# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Submission Info
* Truffle v5.4.33 (core: 5.4.33)
* Ganache v7.0.1
* Solidity 0.6.0 (solc-js) <-- bumped from 0.4.24 in the provided boilerplate
* Node v14.21.1
* Web3.js v1.5.3

## Install

Install truffle and ganache globally
```bash
npm install -g truffle@v5.4.33
npm install -g ganache@v7.0.1
```

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:
```bash
./scripts/1_start_ganacle-cli.sh
truffle migrate --reset --network development
npm run server
truffle test ./test/flightSurety.js
truffle test ./test/oracles.js
```

To use the dapp:
`truffle migrate`
`npm run dapp`

To view dapp:
`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)