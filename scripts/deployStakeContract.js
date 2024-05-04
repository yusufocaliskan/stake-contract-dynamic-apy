const hre = require('hardhat');

async function main() {
  //First Test Token

  //sepolia owner
  const ownerAdress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';
  const tokenAddress = '0xe4670e22Da5e913c8B0Cf267d4d5c2bd7e8c15a5';

  //Local owner
  // const ownerAdress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

  //Deploy vesting schedule
  const StakeContract = await hre.ethers.getContractFactory('GptVerseStaking');

  const stakeContract = await StakeContract.deploy(ownerAdress, tokenAddress);

  console.log('Staking Contract Address', await stakeContract.getAddress());
  console.log('Token Address', tokenAddress);
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
