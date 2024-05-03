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
