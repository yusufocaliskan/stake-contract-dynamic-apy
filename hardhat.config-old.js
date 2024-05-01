// require('@nomicfoundation/hardhat-toolbox');

// /** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: '0.8.24',
//   networks: {
//     hardhat: {
//       forking: {
//         url: 'https://eth-mainnet.g.alchemy.com/v2/f2nqI5oB3QFbFivn0eRvU2asWq8vGhnC',
//       },
//     },
//   },
// };

require('@nomicfoundation/hardhat-toolbox');
// require('@nomiclabs/hardhat-waffle');

module.exports = {
  solidity: '0.8.24',
  networks: {
    hardhat: {
      mining: {
        auto: false,
        interval: [3000, 6000], // Bloklar arası milisaniye cinsinden zaman
      },
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
};