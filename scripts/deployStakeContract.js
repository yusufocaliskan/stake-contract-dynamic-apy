const hre = require('hardhat');

async function main() {
  //First Test Token

  //sepolia owner
  const ownerAdress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';
  const tokenAddress = '0xAc0508781fB306903631Ab5629dbEC4C5DB5b808';

  //Local owner
  // const ownerAdress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

  //Deploy vesting schedule
  const StakeContract = await hre.ethers.getContractFactory('GptVerseStaking');

  const stakeContract = await StakeContract.deploy(ownerAdress, tokenAddress);

  console.log('Staking Contract Address', await stakeContract.getAddress());
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
