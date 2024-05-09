const hre = require('hardhat');

async function main() {
  //First Test Token

  const ownerAdress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';
  const tokenAddress = '0xc8c6414184D3cc65190068C4A12F793AB24cd3F8';

  //Deploy vesting schedule
  const StakeContract = await hre.ethers.getContractFactory('GptVerseStaking');

  const stakeContract = await StakeContract.deploy(ownerAdress, tokenAddress);

  console.log('Staking Contract Address', await stakeContract.getAddress());
  console.log('Token Address', tokenAddress);
  console.log('Owner Address', ownerAdress);
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
