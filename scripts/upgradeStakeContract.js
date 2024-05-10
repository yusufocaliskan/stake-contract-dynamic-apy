const { ethers, upgrades } = require('hardhat');

async function main() {
  const existingProxyAddress = '0xc8c6414184D3cc65190068C4A12F793AB24cd3F8';
  const GptVerseStakeV2 = await ethers.getContractFactory('GptVerseStake');

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
