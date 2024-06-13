const { parseUnits } = require('ethers');
const { ethers, network } = require('hardhat');

describe('Distributed Stake Token Contract', function () {
  let token, stakeContract, stakeAddress;
  let owner, user1, user2, user3, user4, user5;

  before(async function () {
    [owner, user1, user2, user3, user4, user5] = await ethers.getSigners();

    // Deploy token
    const Token = await ethers.getContractFactory('FTT');
    token = await Token.deploy(owner.address);
    const tokenAddress = await token.getAddress();
    console.log('tokenAddress', tokenAddress);

    // Deploy staking contract
    const StakeContract = await ethers.getContractFactory(
      'GptVerseDistributedStake',
    );
    stakeContract = await upgrades.deployProxy(
      StakeContract,
      [owner.address, tokenAddress],
      { initializer: 'initialize' },
    );
    stakeAddress = await stakeContract.getAddress();
    stakeContract = StakeContract.attach(stakeAddress);

    // Transfer token to the user and allow staking contract
    await token.transfer(user1.address, parseUnits('1000', 18));
    await token.transfer(user2.address, parseUnits('1000', 18));
    await token.transfer(user3.address, parseUnits('1000', 18));
    await token.transfer(user4.address, parseUnits('1000', 18));
    await token.transfer(user5.address, parseUnits('100', 18));
    await token.transfer(owner.address, parseUnits('100', 18));
    await token
      .connect(owner)
      .approve(stakeAddress, parseUnits('10000000', 18));

    const balance = await token.balanceOf(user1.address);
    const stakeContractBalance = await token.balanceOf(stakeAddress);
    console.log('BalanceOf User 1 : ', balance);
    console.log('BalanceOf Stake Contract 1 : ', stakeContractBalance);
  });

  it('Create New Stake Pool', async function () {
    await stakeContract.connect(owner).createStakePool(
      'test1', //id
      'Test Stake Pool', //name
      1718382716, //start
      1749832316, //end
      parseUnits('1', 18), //min
      parseUnits('1000', 18), //max
      parseUnits('100', 18), //allocatedAmount
      100, //minAPY 1%
      10000, //maxAPY 100% //All the allocated tokens will be distributed
    );
  });

  it('User1: Stake Token to the Pool', async function () {
    await token.connect(user1).approve(stakeAddress, parseUnits('1000000', 18));
    await token.connect(user2).approve(stakeAddress, parseUnits('1000000', 18));
    await token.connect(user3).approve(stakeAddress, parseUnits('1000000', 18));
    await token.connect(user4).approve(stakeAddress, parseUnits('1000000', 18));
    await token.connect(user5).approve(stakeAddress, parseUnits('1000000', 18));

    await stakeContract.stakeToken(
      user1.address,
      parseUnits('100', 18),
      'test1',
    );
    await stakeContract.stakeToken(
      user2.address,
      parseUnits('100', 18),
      'test1',
    );
    await stakeContract.stakeToken(
      user3.address,
      parseUnits('50', 18),
      'test1',
    );
    await stakeContract.stakeToken(
      user3.address,
      parseUnits('50', 18),
      'test1',
    );
    await stakeContract.stakeToken(
      user4.address,
      parseUnits('50', 18),
      'test1',
    );
    // await stakeContract.stakeToken(
    //   user5.address,
    //   parseUnits('100', 18),
    //   'test1',
    // );
  });

  // it('User Balance After Staking', async function () {
  //   let balance = await token.balanceOf(user1.address);
  //   console.log('Balance After Staking: User1: ', balance);
  //   balance = await token.balanceOf(user2.address);
  //   console.log('Balance After Staking: User2: ', balance);
  //   balance = await token.balanceOf(stakeAddress);
  //   console.log('Balance  Stake Contract: : ', balance);
  // });

  it('Claim Rewards and Check Final Balances', async function () {
    await updateTimestampAsDays(1000);
    let tx = await stakeContract.claimReward4Total(user1.address, 'test1');
    await tx.wait();

    tx = await stakeContract.claimReward4Total(user2.address, 'test1');
    await tx.wait();

    tx = await stakeContract.claimReward4Total(user3.address, 'test1');
    await tx.wait();

    tx = await stakeContract.claimReward4Total(user4.address, 'test1');
    await tx.wait();

    // tx = await stakeContract.claimReward4Total(user5.address, 'test1');
    // await tx.wait();
  });

  it('Get Poool Detail', async function () {
    const pool = await stakeContract.getStakePoolById('test1');
    console.log('Pool ', pool);
  });

  it('Check Final Balances', async function () {
    const balance1 = await token.balanceOf(user1.address);
    console.log('User Balance After Claim: User1: ', balance1);

    const balance2 = await token.balanceOf(user2.address);
    console.log('User Balance After Claim: User2: ', balance2);

    const balance3 = await token.balanceOf(user3.address);
    console.log('User Balance After Claim: User3: ', balance3);

    const balance4 = await token.balanceOf(user4.address);
    console.log('User Balance After Claim: User4: ', balance4);

    const balance5 = await token.balanceOf(user5.address);
    console.log('User Balance After Claim: User5: ', balance5);

    const contractBalance = await token.balanceOf(stakeAddress);
    console.log('Stake Contract Balance: ', contractBalance);
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
