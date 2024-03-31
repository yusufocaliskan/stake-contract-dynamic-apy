const hre = require('hardhat');

async function main() {
  //First Test Token
  const ownerAdress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

  const FirstToken = await hre.ethers.getContractFactory('FTT');

  const firstToken = await FirstToken.deploy(ownerAdress);
  console.log('First Token Contract Address', await firstToken.getAddress());

  //Second Token
  const SeconToken = await hre.ethers.getContractFactory('STT');

  const secondToken = await SeconToken.deploy(ownerAdress);
  console.log('Second Token Contract Address', await secondToken.getAddress());

  //Deploy vesting schedule
  const VestingSchedule = await hre.ethers.getContractFactory(
    'VestingSchedule',
  );

  const gptvRate = 20;
  const vestingSchedule = await VestingSchedule.deploy(
    ownerAdress,
    await firstToken.getAddress(),
    gptvRate,
  );

  console.log(
    'VestingSchedule Contract Address',
    await vestingSchedule.getAddress(),
  );
}

main().catch((error) => {
  console.log(error);
  process.exitCode = 1;
});
