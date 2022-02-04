require('dotenv').config();

const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  contracts_directory: "./contracts",
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gasPrice: 15000000000 
    },
    testnet: {
      provider: () => new HDWalletProvider(
        process.env.PRIVATE_KEY,
        `https://rpc.testnet.fantom.network/`
      ),
      network_id: 0xfa2,
      confirmations: 0,
      timeoutBlocks: 100,
      skipDryRun: true
    },
    mainnet: {
      provider: () => new HDWalletProvider(
        process.env.PRIVATE_KEY,
        `https://rpc.ftm.tools/`
      ),
      network_id: 250,
      confirmations: 5,
      timeoutBlocks: 100,
      skipDryRun: true
    }
  },
  plugins: [
    'truffle-contract-size',
    'truffle-plugin-verify'
  ],
  api_keys: { ftmscan: process.env.FTMSCAN_API_KEY },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000000
        },
        evmVersion: "berlin"
      }
    }
  }
};
