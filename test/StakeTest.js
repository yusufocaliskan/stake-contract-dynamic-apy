const { expect } = require('chai');

describe('StakeTest contract', function () {
  it('should return the string "Selam"', async function () {
    const StakeTest = await ethers.getContractFactory('StakeTest');
    const hardhatToken = await StakeTest.deploy(); // Deploys the contract and waits for it to finish

    const result = await hardhatToken.calculateUserEstimatedRewards(); // Call the method that returns a string
    console.log('Result ---> ', result);
  });
});
