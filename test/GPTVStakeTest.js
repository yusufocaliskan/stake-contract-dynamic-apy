const { parseUnits, formatEther, formatUnits } = require('ethers');
const { ethers, network } = require('hardhat');

describe('StakeTest Contract', function () {
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
    const StakeContract = await ethers.getContractFactory('GptVerseStaking');
    stakeContract = await StakeContract.deploy(owner.address, tokenAddress);
    stakeAddress = await stakeContract.getAddress();

    console.log('stakeAddress', stakeAddress);

    //Transfer token to the user and allovement of the stakeContract
    await token.transfer(user1.address, parseUnits('100000000', 18));
    await token.transfer(stakeAddress, parseUnits('100000000', 18));
    await token
      .connect(user1)
      .approve(stakeAddress, parseUnits('100000000000', 18));

    //get the current balance
    const balance = await token.balanceOf(user1.address);
    const stakeContratBalance = await token.balanceOf(stakeAddress);
    console.log('BalanceOf User 1 : ', balance);
    console.log('BalanceOf Stake Contract 1 : ', stakeContratBalance);

    // await updateTimestamp(1715357702);
    const currentTime = await ethers.provider.getBlock('latest');
    console.log('Current time', currentTime.timestamp);
  });

  it('1. Create New Stake Pool', async function () {
    await stakeContract.createStakePool(
      'test1', //id
      'Test Stake Pool', //name
      1714755564, //start
      1716743058, //end
      5000, //apy 50%
      parseUnits('1', 18), //min
      parseUnits('1000000', 18), //max
    );
  });
  it('calculateStakeRewardWithDefinedAmount===', async () => {
    // await updateTimestampAsDays(365);
    const resp = await stakeContract.calculateStakeRewardWithDefinedAmount(
      'test1', //pool id

      parseUnits('100', 18), //amount
    );

    console.log('Rewad for---> : ', formatEther(resp));
  });
  it('1. Get Stake Pool By Id', async function () {
    const resp = await stakeContract.getStakePoolById(
      'test1', //id
    );
    console.log(resp);
  });

  it('3. Stake Token to the Pool', async function () {
    // await updateTimestampAsDays(10);
    // await updateTimestamp(1745599108);
    await stakeContract.stakeToken(
      user1.address, //user
      parseUnits('1', 18), //amount
      'test1', //pool id
    );
    // await stakeContract.stakeToken(
    //   user1.address, //user
    //   parseUnits('100', 18), //amount
    //   'test1', //pool id
    // );
    // await stakeContract.stakeToken(
    //   user1.address, //user
    //   parseUnits('100', 18), //amount
    //   'test1', //pool id
    // );
    // await stakeContract.stakeToken(
    //   user1.address, //user
    //   parseUnits('100', 18), //amount
    //   'test1', //pool id
    // );
  });

  it('Balance OF the user After Staking --> ', async () => {
    const balance = await token.balanceOf(user1.address);
    const stakeContratBalance = await token.balanceOf(stakeAddress);
    console.log(' Balance Of User 1 : ', balance);
    console.log(
      'New Balance BalanceOf Stake Contract 1 : ',
      stakeContratBalance,
    );
  });
  it('Stakes -->', async function () {
    const resp = await stakeContract.getAllUserStakesByStakePoolsId(
      'test1', //pool id

      user1.address, //user
    );
    console.log('Stakes Of User', resp);
  });

  it('Stakes -->', async function () {
    await updateTimestampAsDays(365);

    const tx = await stakeContract.claimReward4Total(
      user1.address, //user
      'test1', //pool id
    );
    await tx.wait(); // Wait for the transaction to be mined
  });

  it(' getAllUserStakesByStakePoolsId -->', async function () {
    const resp = await stakeContract.getAllUserStakesByStakePoolsId(
      'test1', //pool id

      user1.address, //user
    );
    console.log('Stakes Of User', resp);
  });

  it('New Balance of the user', async () => {
    const balance = await token.balanceOf(user1.address);
    const stakeContratBalance = await token.balanceOf(stakeAddress);
    console.log('NEw Balance Of User 1 : ', formatEther(balance));
    console.log(
      'New Balance BalanceOf Stake Contract 1 : ',
      formatEther(stakeContratBalance),
    );
  });

  it('Check final user balance and rewards', async () => {
    const finalBalance = await token.balanceOf(user1.address);
    console.log('Final User Balance: ', formatEther(finalBalance));

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
