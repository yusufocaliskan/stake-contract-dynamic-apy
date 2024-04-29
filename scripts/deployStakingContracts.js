const hre = require('hardhat');

async function main() {
  //First Test Token

  //sepolia owner
  const ownerAdress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';
  const tokenAddress = '0x0165878A594ca255338adfa4d48449f69242Eb8F';
  //Local owner
  // const ownerAdress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

  const FirstToken = await hre.ethers.getContractFactory('FTT');

  const firstToken = await FirstToken.deploy(ownerAdress);
  console.log(
    'First Token Contract Address (GPTV)',
    await firstToken.getAddress(),
  );

  //Deploy Staking contract
  const GptVerseStaking = await hre.ethers.getContractFactory(
    'GptVerseStaking',
  );

  const gptVerseStaking = await GptVerseStaking.deploy(
    ownerAdress,
    tokenAddress,
  );

  console.log(
    'gptVerseStaking Contract Address',
    await gptVerseStaking.getAddress(),
  );
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
