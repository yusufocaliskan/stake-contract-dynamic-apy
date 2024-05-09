const { expect } = require('chai');
const { parseUnits, formatEther, formatUnits, parseEther } = require('ethers');
const { ethers, network } = require('hardhat');
const { boolean } = require('hardhat/internal/core/params/argumentTypes');

describe('Vesting Schedule Contract', function () {
  let token, vestingContract, vestingAddress;
  let owner, user1, user2;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    //deplot token
    const Token = await ethers.getContractFactory('FTT');
    token = await Token.deploy(owner.address);
    const tokenAddress = await token.getAddress();
    console.log('tokenAddress', tokenAddress);

    //Deploy staking contract
    const VestingContract = await ethers.getContractFactory('VestingSchedule');
    vestingContract = await VestingContract.deploy(
      owner.address,
      tokenAddress,
      40,
    );
    vestingAddress = await vestingContract.getAddress();

    console.log('Vesting Address', vestingAddress);

    //Transfer token to the user and allovement of the stakeContract
    await token.transfer(user1.address, parseUnits('100000000', 18));
    await token.transfer(vestingAddress, parseUnits('100000000', 18));
    await token
      .connect(user1)
      .approve(vestingAddress, parseUnits('100000000000', 18));

    //get the current balance
    const balance = await token.balanceOf(user1.address);
    const vestingContractBalance = await token.balanceOf(vestingAddress);
    console.log('BalanceOf User 1 : ', balance);
    console.log('BalanceOf Vesting Contract 1 : ', vestingContractBalance);

    // await updateTimestamp(1715357702);
    const currentTime = await ethers.provider.getBlock('latest');
    console.log('Current time', currentTime.timestamp);
  });

  it(' Create New Event', async function () {
    await vestingContract.createNewEvent(
      'Test Event', //name
      'event1', //id
      50, //tge
      6000, //vesting
      30, //cliff
      '0x0', //privateAccount
    );
    await vestingContract.createNewEvent(
      'Pre Sale', //name
      'pre-sale', //id
      50, //tge
      400, //vesting
      30, //cliff
      '0x0', //privateAccount
    );
  });

  it(' Get All Events', async function () {
    const resp = await vestingContract.getAllEvents();
    console.log('All Events:', resp);
  });
  it('Get Event By ID', async function () {
    const resp = await vestingContract.getEventById(
      'event1', //id
    );
    console.log('Event 1', resp);
  });
  it('addPrivateVestingSchedule', async function () {
    const resp = await vestingContract.addPrivateVestingSchedule(
      user1.address, //id
      parseEther('1'),
      'event1',
      0,
      0,
    );
  });
  it('getVestingSchedule', async function () {
    const resp = await vestingContract.getVestingSchedule(
      'event1',
      user1.address, //id
    );
    console.log('User 1 Vesting', resp);
  });

  it('Before Cliff Started. Should give the TGE amount', async function () {
    const currentTime = (await ethers.provider.getBlock('latest')).timestamp;

    const resp = await vestingContract.claim(
      'event1',
      user1.address, //id
    );
  });
  it('After TGE, should return 0 amount', async function () {
    const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
    await updateTimestamp(currentTime + 6000);
    const resp = await vestingContract.claim(
      'event1',
      user1.address, //id
    );
  });
  // it('After cliff time start', async function () {
  //   const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
  //   await updateTimestamp(currentTime + 30);
  //   const resp = await vestingContract.claim(
  //     'event1',
  //     user1.address, //id
  //   );
  // });

  // it('Second CLAIMM after Cliff', async function () {
  //   const currentTime = (await ethers.provider.getBlock('latest')).timestamp;

  //   await updateTimestamp(currentTime + 1900);
  //   const resp = await vestingContract.claim(
  //     'event1',
  //     user1.address, //id
  //   );
  // });
  // it('Second CLAIMM after Cliff', async function () {
  //   const currentTime = (await ethers.provider.getBlock('latest')).timestamp;

  //   await updateTimestamp(currentTime + 10000);

  //   const resp = await vestingContract.claim(
  //     'event1',
  //     user1.address, //id
  //   );
  // });
  // it('Second CLAIMM after Cliff', async function () {
  //   const currentTime = (await ethers.provider.getBlock('latest')).timestamp;

  //   await updateTimestamp(currentTime + 600000);
  //   const resp = await vestingContract.claim(
  //     'event1',
  //     user1.address, //id
  //   );
  // });

  it('getVestingSchedule', async function () {
    const resp = await vestingContract.getVestingSchedule(
      'event1',
      user1.address, //id
    );
    console.log(resp);
    console.log('Claimed Amount', formatEther(resp[5].toString()));
  });

  it('New Balance of the user', async () => {
    const balanceOfUser2 = await token.balanceOf(user2.address);
    const balance = await token.balanceOf(user1.address);
    const vestingBalance = await token.balanceOf(vestingAddress);
    console.log('NEw Balance Of User 1 : ', formatEther(balance));
    console.log('NEw Balance Of User 2 : ', formatEther(balanceOfUser2));
    console.log(
      'New Balance BalanceOf Vesting Contract 1 : ',
      formatEther(vestingBalance),
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
