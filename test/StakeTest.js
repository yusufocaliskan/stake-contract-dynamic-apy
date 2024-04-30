const { expect } = require('chai');
const chai = require('chai');
const { ethers } = require('hardhat');
const BN = require('bn.js');

// chai ve BN (BigNumber) için uyumluluk sağlama
chai.use(require('chai-bn')(BN));

describe('StakeTest Contract', function () {
  let stakeTest;
  let stakeAmount = 1000;
  let apyRate = 2000;
  let startTime = 1714406656;
  let endTime = 1745942656;
  let currentTime = Math.floor(Date.now() / 1000);

  // startTime = currentTime - 86400; // a day before
  // endTime = currentTime + 86400; // a day later

  before(async function () {
    const StakeTest = await ethers.getContractFactory('StakeTest');
    stakeTest = await StakeTest.deploy();
  });

  it('should correctly calculate the total rewards for the entire period', async function () {
    const expectedRewards = await stakeTest.calculateTotalRewards(
      stakeAmount,
      apyRate,
      startTime,
      endTime,
    );

    expect(expectedRewards).to.be.a.bignumber;
  });

  it('should correctly calculate the current rewards up to now', async function () {
    const expectedCurrentRewards = await stakeTest.calculateCurrentRewards(
      stakeAmount,
      apyRate,
      startTime,
    );
    console.log('expectedCurrentRewards', expectedCurrentRewards);
    expect(expectedCurrentRewards).to.be.a.bignumber;
  });
});
