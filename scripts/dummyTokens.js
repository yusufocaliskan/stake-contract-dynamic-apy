const hre = require('hardhat');

async function main() {
  //First Test Token

  //sepolia owner
  const ownerAdress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

  const FirstToken = await hre.ethers.getContractFactory('FTT');

  const firstToken = await FirstToken.deploy(ownerAdress);
  console.log(
    'First Token Contract Address (GPTV)',
    await firstToken.getAddress(),
  );
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
