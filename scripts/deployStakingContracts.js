const hre = require('hardhat');

async function main() {
  //Local owner
  const ownerAdress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const tokenAddress = '0x9A676e781A523b5d0C0e43731313A708CB607508';

  //Deploy Staking contract
  const GptVerseStaking = await hre.ethers.getContractFactory(
    'GptVerseStaking',
  );

  const gptVerseStaking = await GptVerseStaking.deploy(
    ownerAdress,
    tokenAddress,
  );
  console.log('Token Address', tokenAddress);
  console.log(
    'gptVerseStaking Contract Address',
    await gptVerseStaking.getAddress(),
  );
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
