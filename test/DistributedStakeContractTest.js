const { parseUnits } = require('ethers');
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
      1720265186, //start
      1749197262, //end
      parseUnits('1', 18), //min
      parseUnits('1000000', 18), //max
      parseUnits('1000', 18), //allocatedAmount
      100, //minAPY 1%
      5000, //maxAPY 50%
    );
  });

  it('User1: Stake Token to the Pool', async function () {
    // await updateTimestampAsDays(10);
    // await updateTimestamp(1745599108);

    await token.connect(user1).approve(stakeAddress, parseUnits('1000000', 18));

    let amount;
    amount = parseUnits('300', 18);
    await stakeContract.stakeToken(
      user1.address, //user
      amount, //amount
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

    // await stakeContract.stakeToken(
    //   user2.address, //user
    //   parseUnits('200', 18), //amount
    //   'test1', //pool id
    // );
    await stakeContract.stakeToken(
      user2.address, //user
      parseUnits('400', 18), //amount
      'test1', //pool id
    );
  });

  it('claimReward4Total User1-->', async function () {
    await updateTimestampAsDays(365);

    const tx = await stakeContract.claimReward4Total(
      user1.address, //user
      'test1', //pool id
    );
    await tx.wait(); // Wait for the transaction to be mined
  });

  it('calculateStakeRewardWithDefinedAmount-->', async function () {
    const calculatedReward =
      await stakeContract.calculateStakeRewardWithDefinedAmount(
        'test1', //pool id
        parseUnits('400', 18),
      );
    console.log('calculatedReward', calculatedReward);
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
