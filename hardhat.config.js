require('@nomicfoundation/hardhat-toolbox');
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
    // bscMainnet: {
    //   url: 'https://bsc-dataseed.binance.org/',
    //   accounts: ['YOUR_BSC_PRIVATE_KEY'],
    // },
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
