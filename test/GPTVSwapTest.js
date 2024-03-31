const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('GPTV Swap Functionality', function () {
  let vestingSchedule;
  let owner, addr1;

  beforeEach(async function () {
    // Assuming you have ethers.js contract factories for your mock DAI and USDC
    const VestingSchedule = await ethers.getContractFactory('VestingSchedule');

    [owner, addr1] = await ethers.getSigners();
    console.log(owner);

    // vestingSchedule = await VestingSchedule.deploy();
    console.log('gptvSwap--->', vestingSchedule);

    // await gptvSwap.deployed()
  });

  // it('should swap DAI to USDC successfully', async function () {});
});
