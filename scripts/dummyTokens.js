const hre = require('hardhat');

async function main() {
  const ownerAdress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';

  //Second Token
  const SeconToken = await hre.ethers.getContractFactory('ST');

  const secondToken = await SeconToken.deploy(ownerAdress);
  console.log('Second Token Contract Address', await secondToken.getAddress());
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
