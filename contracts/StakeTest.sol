// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract StakeTest {


   function calculateUserEstimatedRewards() public view returns(uint256) {
        uint256 userReward;
        uint _stakeAmount = 1000;
        uint _apyRate = 2000;  
        uint _lastStakeTime = 1714403595;
        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - _lastStakeTime;
        
        uint256 secondlyRate = calculateSecondlyAPY(_apyRate);

        userReward = uint128(_stakeAmount * (secondlyRate * elapsedTime) / 1e18);

        return userReward;
    }

    function testoo()public pure returns(uint){
        return 2012;
    }

    function calculateTotalRewards(uint _stakeAmount, uint _apyRate, uint _startStakeTime, uint _endStakeTime) public pure returns(uint256) {
        uint256 totalReward;
        uint256 elapsedTime = _endStakeTime - _startStakeTime;  

        uint256 secondlyRate = calculateSecondlyAPY(_apyRate);  
        totalReward = _stakeAmount * secondlyRate * elapsedTime / 1e18;  

        return totalReward; 
    }

    
    function testCalculateTotalRewards(uint _stakeAmount, uint _apyRate, uint _days) public pure returns(uint256) {
        uint256 totalReward;
        

        uint256 daily_rate = _apyRate / 365;
        totalReward = _stakeAmount * (daily_rate /10000) * _days;

        return totalReward;  
    }




    
    function calculateSecondlyAPY(uint _apy) public pure returns (uint256) {
        return (_apy * 1e18) / 365 / 24 / 60 / 60;
    }   
}