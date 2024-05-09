# Hardhat Project

run the below command to deploy the stake contract on sepolia network.

## Stake Contract

Stake Contract
`npx hardhat run scripts/deployStakeContract.js  --network bscMainnet`

## Upgradable Stake Contract

Deploy: Stake Contract
`npx hardhat run scripts/deployUpgradeableStakeContract.js  --network bscMainnet`

Upgrade: The upgradable Stake Contrat
`npx hardhat run scripts/upgradeStakeContract.js --network bscTestnet`

## Vesting Contract

Vesting Contract
`npx hardhat run scripts/deployVestingContract.js  --network bscMainnet`

## Verify & Publish

`npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS "Constructor Argument 1" "Constructor Argument 2"`

Testing comman
`npx hardhat test test/GPTVStakeTest.js`  
`npx hardhat test test/GPTVVestingTest.js`

Start the hardhat node on local (if you wish)
`npx hardhat node`

Others

```shell
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
