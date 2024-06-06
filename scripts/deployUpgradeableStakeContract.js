const { ethers, upgrades } = require('hardhat');

async function main() {
  const ownerAddress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';
  const tokenAddress = '0x763Ba4A177B7a548864aAE8Fe76F247279DD7366';

  const GptVerseStake = await ethers.getContractFactory('GptVerseStake');

  const gptVerseStakeProxy = await upgrades.deployProxy(
    GptVerseStake,
    [ownerAddress, tokenAddress],
    { initializer: 'initialize' },
  );

  console.log(
    'gptVerseStakeProxy proxy deployed to:',
    await gptVerseStakeProxy.getAddress(),
  );
  console.log('Token Address:', tokenAddress);
  console.log('Owner Address:', ownerAddress);
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
