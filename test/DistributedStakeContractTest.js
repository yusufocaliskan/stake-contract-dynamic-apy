const { expect } = require('chai');
const { parseUnits, formatEther } = require('ethers');
const { ethers, network } = require('hardhat');

describe('Distributed Stake Token Contract', function () {
  let token, stakeContract, stakeAddress;
  let owner, user1, user2;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    //deplot token
    const Token = await ethers.getContractFactory('FTT');
    token = await Token.deploy(owner.address);
    const tokenAddress = await token.getAddress();
    console.log('tokenAddress', tokenAddress);

    //Deploy staking contract
    const StakeContract = await ethers.getContractFactory(
      'GptVerseDistributedStake',
    );
    stakeContract = await upgrades.deployProxy(
      StakeContract,
      [owner.address, tokenAddress],
      { initializer: 'initialize' },
    );

    // stakeContract = await StakeContract.deploy(owner.address, tokenAddress);
    stakeAddress = await stakeContract.getAddress();
    stakeContract = StakeContract.attach(stakeAddress);

    //Transfer token to the user and allovement of the stakeContract
    await token.transfer(user1.address, parseUnits('2000', 18));
    await token.transfer(user2.address, parseUnits('2000', 18));
    // await token.transfer(stakeAddress, parseUnits('100000000', 18));
    await token
      .connect(owner)
      .approve(stakeAddress, parseUnits('10000000', 18));

    //get the current balance
    const balance = await token.balanceOf(user1.address);
    const stakeContratBalance = await token.balanceOf(stakeAddress);
    console.log('BalanceOf User 1 : ', balance);
    console.log('BalanceOf Stake Contract 1 : ', stakeContratBalance);

    // await updateTimestamp(1715357702);
    const currentTime = await ethers.provider.getBlock('latest');
    // console.log('currentTime', currentTime);
    console.log('owner.address', owner.address);
  });

  it('Create New Stake Pool', async function () {
    await stakeContract.connect(owner).createStakePool(
      'test1', //id
      'Test Stake Pool', //name
      1717661262, //start
      1749197262, //end
      parseUnits('1', 18), //min
      parseUnits('1000000', 18), //max
      parseUnits('1000', 18), //allocatedAmount
      100, //minAPY 1%
      5000, //maxAPY 50%
    );
  });

  // it('calculateStakeRewardWithDefinedAmount===', async () => {
  //   // await updateTimestampAsDays(365);
  //   const resp = await stakeContract.calculateStakeRewardWithDefinedAmount(
  //     'test1', //pool id

  //     parseUnits('100', 18), //amount
  //   );

  //   console.log('Rewad for---> : ', formatEther(resp));
  // });
  // it('Get Stake Pool By Id', async function () {
  //   const resp = await stakeContract.getStakePoolById(
  //     'test1', //id
  //   );
  //   console.log(resp);
  // });

  it('User1: Stake Token to the Pool', async function () {
    // await updateTimestampAsDays(10);
    // await updateTimestamp(1745599108);

    await token.connect(user1).approve(stakeAddress, parseUnits('1000000', 18));

    let amount;
    amount = parseUnits('100', 18);
    await stakeContract.stakeToken(
      user1.address, //user
      amount, //amount
      'test1', //pool id
    );

    await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('100', 18), //amount
      'test1', //pool id
    );

    console.log('User1 Staked', amount);
  });
  it('User Balance Apter Staking', async function () {
    const balance = await token.balanceOf(user1.address);
    console.log('Balance After Staking: User1: ', balance);
  });
  it('User2: Stake Token to the Pool', async function () {
    // await updateTimestampAsDays(10);
    // await updateTimestamp(1745599108);

    await token.connect(user2).approve(stakeAddress, parseUnits('1000000', 18));

    const amount = parseUnits('200', 18);
    await stakeContract.stakeToken(
      user2.address, //user
      amount, //amount
      'test1', //pool id
    );
    // await stakeContract.stakeToken(
    //   user1.address, //user
    //   parseUnits('200', 18), //amount
    //   'test1', //pool id
    // );

    console.log('User2 Staked', amount);
  });
  // it('Second User: Stake Token to the Pool', async function () {
  //   // await updateTimestampAsDays(10);
  //   // await updateTimestamp(1745599108);

  //   await token.connect(user2).approve(stakeAddress, parseUnits('1000000', 18));

  //   await stakeContract.stakeToken(
  //     user2.address, //user
  //     parseUnits('800', 18), //amount
  //     'test1', //pool id
  //   );
  //   console.log('User Staked', parseUnits('800', 18));
  // });
  // it('User Balance Apter Staking', async function () {
  //   const balance = await token.balanceOf(user2.address);
  //   console.log('Balance After Staking: User2: ', balance);
  // });
  // it('Stakes in Stake Pools', async function () {
  //   const resp = await stakeContract.listAllStakesInPool('test1');
  //   console.log(resp);
  // });
  // it('Total Length Stakes in the pool', async function () {
  //   const resp = await stakeContract.lengthStakesInPool('test1');
  //   console.log(resp);
  // });
  // it('Balance OF the user After Staking --> ', async () => {
  //   const balance = await token.balanceOf(user1.address);
  //   const stakeContratBalance = await token.balanceOf(stakeAddress);
  //   console.log(' Balance Of User 1 : ', balance);
  //   console.log(
  //     'New Balance BalanceOf Stake Contract 1 : ',
  //     stakeContratBalance,
  //   );
  // });
  // it('Stakes -->', async function () {
  //   const resp = await stakeContract.getAllUserStakesByStakePoolsId(
  //     'test1', //pool id

  //     user1.address, //user
  //   );
  //   console.log('Stakes Of User', resp);
  // });

  it('claimReward4Total User1-->', async function () {
    await updateTimestampAsDays(365);

    const tx = await stakeContract.claimReward4Total(
      user1.address, //user
      'test1', //pool id
    );
    await tx.wait(); // Wait for the transaction to be mined
  });

  it('claimReward4Total User2-->', async function () {
    await updateTimestampAsDays(365);

    const tx = await stakeContract.claimReward4Total(
      user2.address, //user
      'test1', //pool id
    );
    await tx.wait(); // Wait for the transaction to be mined
  });
  it('User Balance After Claim', async function () {
    const balance = await token.balanceOf(user1.address);
    console.log('User Balance After Claim: User1: ', balance);
  });
  it('User2 Balance After Claim', async function () {
    const balance = await token.balanceOf(user2.address);
    console.log('User Balance After Claim: User2: ', balance);
  });

  // it('claimReward4Total User2-->', async function () {
  //   await updateTimestampAsDays(365);

  //   const tx = await stakeContract.claimReward4Total(
  //     user2.address, //user
  //     'test1', //pool id
  //   );
  //   await tx.wait(); // Wait for the transaction to be mined
  // });
  // it('Stakes USEr 2-->', async function () {
  //   await updateTimestampAsDays(365);

  //   const tx = await stakeContract.claimReward4Total(
  //     user2.address, //user
  //     'test1', //pool id
  //   );
  //   await tx.wait(); // Wait for the transaction to be mined
  // });
  // it(' getAllUserStakesByStakePoolsId -->', async function () {
  //   const resp = await stakeContract.getAllUserStakesByStakePoolsId(
  //     'test1', //pool id

  //     user1.address, //user
  //   );
  //   console.log('Stakes Of User', resp);
  // });

  // it(' Is Pool Exists -->', async function () {
  //   const resp = await stakeContract.checkIsPoolExists(
  //     'test1', //pool id
  //   );

  //   console.log('Result: test1 pool', resp);
  //   expect(resp).equal(true);
  // });

  // it(' getTotalRewardsInThePoolOfUser -->', async function () {
  //   const resp = await stakeContract.getTotalRewardsInThePoolOfUser(
  //     user1.address,
  //     'test1', //pool id
  //   );

  //   console.log('Total Rewards', resp);
  //   // expect(resp).equal(true);
  // });
  // it('withdraw token from contract', async () => {
  //   await stakeContract.withdraw(user2.address, 1);
  // });

  // it('New Balance of the user', async () => {
  //   const balanceOfUser2 = await token.balanceOf(user2.address);
  //   const balance = await token.balanceOf(user1.address);
  //   const stakeContratBalance = await token.balanceOf(stakeAddress);
  //   console.log('NEw Balance Of User 1 : ', formatEther(balance));
  //   console.log('NEw Balance Of User 2 : ', formatEther(balanceOfUser2));
  //   console.log(
  //     'New Balance BalanceOf Stake Contract 1 : ',
  //     formatEther(stakeContratBalance),
  //   );
  // });
  // it('getBalanceOfTheContract', async () => {
  //   const balance = await stakeContract.getBalanceOfTheContract();
  //   console.log('BalanceOf The Stake Contract : ', formatEther(balance));
  // });

  it('Check final user balance and rewards', async () => {
    const finalBalance = await token.balanceOf(user1.address);
    console.log('Final User Balance: ', finalBalance);

    const stakes = await stakeContract.getAllUserStakesByStakePoolsId(
      'test1',
      user1.address,
    );
    console.log(
      'Final Stakes Details: ',
      stakes.map((stake) => ({
        amount: formatEther(stake.stakeAmount),
        reward: formatEther(stake.stakeReward),
      })),
    );
  });
  it('user 2: Check final user balance and rewards', async () => {
    const finalBalance = await token.balanceOf(user1.address);
    console.log('Final User2 Balance: ', formatEther(finalBalance));

    const stakes = await stakeContract.getAllUserStakesByStakePoolsId(
      'test1',
      user2.address,
    );
    console.log(
      'Final Stakes Details: ',
      stakes.map((stake) => ({
        amount: formatEther(stake.stakeAmount),
        reward: formatEther(stake.stakeReward),
      })),
    );
  });
});

const updateTimestampAsDays = async (days) => {
  const daysLater =
    (await ethers.provider.getBlock('latest')).timestamp + days * 86400;
  await network.provider.send('evm_setNextBlockTimestamp', [daysLater]);
  await network.provider.send('evm_mine');
};
const updateTimestamp = async (timeStamp) => {
  await network.provider.send('evm_setNextBlockTimestamp', [timeStamp]);
  await network.provider.send('evm_mine');
};
