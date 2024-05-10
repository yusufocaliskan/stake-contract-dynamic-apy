const { ethers, upgrades } = require('hardhat');

async function main() {
  const ownerAddress = '0xeB80Df01fc3a988E88a1f70a74e5e0a0E77c1408';
  const tokenAddress = '0x1F56eFffEe38EEeAE36cD38225b66c56E4D095a7';

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
