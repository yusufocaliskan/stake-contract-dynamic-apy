require('@nomicfoundation/hardhat-toolbox');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: '0.8.24',
  networks: {
    hardhat: {
      forking: {
        url: 'https://eth-mainnet.g.alchemy.com/v2/f2nqI5oB3QFbFivn0eRvU2asWq8vGhnC',
      },
    },
  },
};

// require('@nomicfoundation/hardhat-toolbox');

// /** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: '0.8.24',
//   networks: {
//     sepolia: {
//       url: 'https://eth-sepolia.g.alchemy.com/v2/2zPaNqWXrpdn9VRnUH0r1eQMWSJi__cR',

//       accounts: [
//         //Account 1
//         '--',
//         //SepoliaTest
//         '--',
//       ],
//     },
//   },
// };
