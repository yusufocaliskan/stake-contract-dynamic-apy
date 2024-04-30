// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "hardhat/console.sol";

contract StakeTest {

    //Total reward that the use would have at the end of the stake pool time
    function calculateTotalRewards(uint _stakeAmount, uint _apyRate, uint _startStakeTime, uint _endStakeTime) public pure returns(uint256) {

        uint256 elapsedTime = _endStakeTime - _startStakeTime;
        uint256 daysElapsed = elapsedTime / 60 / 60 / 24; 
        uint256 dailyRate = calculateDailyAPY(_apyRate);

        uint256 totalReward = _stakeAmount * dailyRate * daysElapsed / 1e18;

        console.log("amount --->", _stakeAmount);
        console.log("apy --->", _apyRate);
        console.log("start --->", _startStakeTime);
        console.log("end --->", _endStakeTime);
        console.log("elapsedTime --->", elapsedTime);
        console.log("daysElapsed --->", daysElapsed);
        console.log("dailyRate --->", dailyRate);
        console.log("totalReward --->", totalReward);

        return totalReward;
    }

    function calculateCurrentRewards(uint _stakeAmount, uint _apyRate, uint _startStakeTime) public view returns(uint256) {
        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - _startStakeTime;
        uint256 daysElapsed = elapsedTime / 86400;  
        uint256 dailyRate = calculateDailyAPY(_apyRate);
        uint256 currentReward = _stakeAmount * dailyRate * daysElapsed / 1e18;  

        console.log("amount --->", _stakeAmount);
        console.log("apy --->", _apyRate);
        console.log("start --->", _startStakeTime);
        console.log("elapsedTime --->", elapsedTime);
        console.log("daysElapsed --->", daysElapsed);
        console.log("dailyRate --->", dailyRate);
        console.log("currentReward --->", currentReward);

        return currentReward;
    }


    // Günlük APY'yi hesaplar
    function calculateDailyAPY(uint _apyRate) public pure returns (uint256) {
        return (_apyRate * 1e18) / 365;
    }

    // Test edilen ödüllerin eşitliğini kontrol eder
    function testRewardEquality(uint _stakeAmount, uint _apyRate, uint _startStakeTime, uint _endStakeTime) public view returns (uint256, uint256) {
        uint256 totalRewards = calculateTotalRewards(_stakeAmount, _apyRate, _startStakeTime, _endStakeTime);
        uint256 currentRewards = calculateCurrentRewards(_stakeAmount, _apyRate, _startStakeTime);
        return(totalRewards,  currentRewards); 
    }
}
