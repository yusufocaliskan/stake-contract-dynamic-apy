# Hardhat Project

run the below command to deploy the stake contract on sepolia network.

Stake Contract
`npx hardhat run scripts/deployStakeContract.js  --network bscMainnet`

Vesting Contract
`npx hardhat run scripts/deployVestingContract.js  --network bscMainnet`

Verfiying
`npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS "Constructor Argument 1" "Constructor Argument 2"`

Testing comman
`npx hardhat test`

Start the hardhat node on local (if you wish)
`npx hardhat node`

Others

```shell
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
