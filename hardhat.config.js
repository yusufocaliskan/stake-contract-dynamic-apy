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
      url: 'https://eth-sepolia.g.alchemy.com/v2/Qcv6SBRNZ88NyVbDfWB0uTapQvyk9zg1',

      accounts: [
        //Account 1
        '45cf679fedc85572662183789e70f9b60dc762dc5627945f7e856e83f2ff4fcb',
        //SepoliaTest
        'ff300ac1a84b7ece67f1cd72ad9671537f35056cf0a7a80b645901b25245b380',
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
        '45cf679fedc85572662183789e70f9b60dc762dc5627945f7e856e83f2ff4fcb',
        //BncTester
        'ff300ac1a84b7ece67f1cd72ad9671537f35056cf0a7a80b645901b25245b380',
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
