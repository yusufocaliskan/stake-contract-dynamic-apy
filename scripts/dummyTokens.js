const hre = require('hardhat');

async function main() {
  //First Test Token

  //sepolia owner
  const ownerAdress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';

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
