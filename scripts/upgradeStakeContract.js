const { ethers, upgrades } = require('hardhat');

async function main() {
  const existingProxyAddress = '0x3280F34AE438121018aEc130be19F2D1db353AB9';
  const GptVerseStakeV2 = await ethers.getContractFactory('GptVerseStakeV2');

  const upgradedProxy = await upgrades.upgradeProxy(
    existingProxyAddress,
    GptVerseStakeV2,
  );

  console.log(
    'gptVerseStakeProxy proxy deployed to:',
    await upgradedProxy.getAddress(),
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
