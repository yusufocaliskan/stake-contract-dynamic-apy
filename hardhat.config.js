require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
const { mnemonic, bscscanApiKey } = require('./secret.json');

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      // mining: {
      //   auto: false,
      //   interval: [3000, 6000],
      // },
    },
    sepolia: {
      url: '--',

      accounts: [
        //Account 1
        '--',
        //SepoliaTest
        '--',
      ],
    },
    bscMainnet: {
      url: 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      gasPrice: 20000000000,
      accounts: { mnemonic: mnemonic },
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-1-s1.bnbchain.org:8545',
      chainId: 97,
      // gasPrice: 20000000000,
      accounts: [
        //BncOwner
        '--',
        //BncTester
        '--',
      ],
    },
  },
  etherscan: {
    apiKey: bscscanApiKey,
  },
  gasReporter: {
    enabled: true,
    currency: 'BNB',
    coinmarketcap: '39a4f3ef-b65d-4a71-8cba-31e5217a8365',
    gasPrice: 20,
  },
  solidity: {
    version: '0.8.24',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 40000,
  },
};
