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
        'ee074edc1640c22fced718a3bc83ef4521d94044e88f9ded058c6862d15a97e4',
        //BncTester
        '85805116e6d268c83adeba6d664cd66b63d4a93886cd50baa01ce8fbde5b37f9',
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
