const { expect } = require('chai');
const { parseUnits, formatEther, formatUnits } = require('ethers');
const { ethers } = require('hardhat');

describe('StakeTest Contract', function () {
  let token, stakeContract;
  let owner, user1, user2;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    //deplot token
    const Token = await ethers.getContractFactory('FTT');
    token = await Token.deploy(owner.address);
    const tokenAddress = await token.getAddress();

    //Deploy staking contract
    const StakeContract = await ethers.getContractFactory('GptVerseStaking');
    stakeContract = await StakeContract.deploy(owner.address, tokenAddress);
    const stakeAddress = await stakeContract.getAddress();

    //Transfer token to the user and allovement of the stakeContract
    await token.transfer(user1.address, parseUnits('100000', 18));
    await token.connect(user1).approve(stakeAddress, parseUnits('10000', 18));

    //get the current balance
    const balance = await token.balanceOf(user1.address);
    const stakeContratBalance = await token.balanceOf(stakeAddress);
    console.log('BalanceOf User 1 : ', balance);
    console.log('BalanceOf Stake Contract 1 : ', stakeContratBalance);
  });

  it('1. Create New Stake Pool', async function () {
    const result = await stakeContract.createStakePool(
      'test1', //id
      'Test Stake Pool', //name
      1682936598, //start
      1746094998, //end
      5000, //apy
      parseUnits('1', 18), //min
      parseUnits('1000000', 18), //max
    );

    await result.wait();
  });

  it('2. Get List of Pools', async function () {
    const resp = await stakeContract.getAllStakePools();
    console.log('Stake Pools-->', resp);
  });
  it('3. Stake Token to the Pool', async function () {
    await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('1', 18), //amount
      'test1', //pool id
      1714558998,
    );
    await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('1', 18), //amount
      'test1', //pool id
      1682936598,
    );
  });

  it("4. Get All the User's Stake", async function () {
    const resp = await stakeContract.getAllUserStakesByStakePoolsId(
      'test1', //pool id
      user1.address, //user
    );
    console.log('Users Stakes : test1 pool', resp);
  });

  it('5. calculateTotalRewards', async function () {
    // const resp = await stakeContract.calculateTotalRewardsOfStake(
    //   user1.address, //user
    //   'test1', //pool id
    //   1,
    // );
    const resp = await stakeContract.calculateTotalRewardsOfStake(
      user1.address, //user
      'test1', //pool id
      2,
    );

    console.log('calculateTotalRewards --> ', formatUnits(resp, 18));
  });
  it('6. calculateCurrentStakeRewardByStakeId', async function () {
    const resp = await stakeContract.calculateCurrentStakeRewardByStakeId(
      user1.address, //user
      'test1', //pool id
      2,
    );
    console.log(
      'calculateCurrentStakeRewardByStakeId --> ',
      formatUnits(resp, 18),
    );
  });
});
