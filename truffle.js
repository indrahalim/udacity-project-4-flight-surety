var HDWalletProvider = require("truffle-hdwallet-provider");
const fs = require("fs");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

try {
  var envMnemonic = fs.readFileSync(".secret").toString().trim();
  if (envMnemonic.length > 0) {
    mnemonic = envMnemonic;
  }
} catch(e) {
  console.log('no .secret file found, using default mnemonic');
}

module.exports = {
  networks: {
    develop: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:9545/", 0, 50);
      },
      network_id: '*',
      gas: 9999999
    },
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      gas: 9999999
    }
  },
  compilers: {
    solc: {
      version: "^0.6.0"
    }
  }
};