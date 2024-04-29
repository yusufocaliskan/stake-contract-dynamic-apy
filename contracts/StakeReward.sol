// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingRewards {

    // Mapping of a staker's address to their current stake
    mapping(address => uint256) public stakes;
    // Mapping of a staker's address to their reward debt (see below for explanation)
    mapping(address => uint256) public rewardDebt;
    // Total staked amount
    uint256 public totalStakes;
    // Accumulated rewards per staked token unit
    uint256 public accRewardPerShare;
    // Total rewards that have been added to the contract
    uint256 public totalRewards;

    // Event emitted when a user stakes tokens
    event Stake(address indexed user, uint256 amount);
    // Event emitted when a user withdraws their stake
    event Withdraw(address indexed user, uint256 amount);
    // Event emitted when a user claims rewards
    event ClaimReward(address indexed user, uint256 reward);

    // Function to stake tokens
    function stake(uint256 _amount) external {
        // Update rewards for everyone before changing state
        updateRewards();
        // If the user already has staked tokens, send their current rewards
        if (stakes[msg.sender] > 0) {

        uint256 pending = stakes[msg.sender] * accRewardPerShare / 1e12 - rewardDebt[msg.sender];
        if(pending > 0) {
        // Send reward to the staker
            payable(msg.sender).transfer(pending);
            emit ClaimReward(msg.sender, pending);
        }
        }
        // Increase the user's stake and the total stake
        stakes[msg.sender] += _amount;
        totalStakes += _amount;
        // Update the user's reward debt
        rewardDebt[msg.sender] = stakes[msg.sender] * accRewardPerShare / 1e12;
        emit Stake(msg.sender, _amount);
    }

    // Function to withdraw stake
    function withdraw(uint256 _amount) external {
        require(stakes[msg.sender] >= _amount, "Withdrawal amount exceeds stake");
        // Update rewards for everyone before changing state
        updateRewards();
        // Calculate and send pending rewards
        uint256 pending = stakes[msg.sender] * accRewardPerShare / 1e12 - rewardDebt[msg.sender];
        if(pending > 0) {
        payable(msg.sender).transfer(pending);
        emit ClaimReward(msg.sender, pending);
        }
        // Decrease the user's stake and the total stake
        stakes[msg.sender] -= _amount;
        totalStakes -= _amount;
        // Update the user's reward debt
        rewardDebt[msg.sender] = stakes[msg.sender] * accRewardPerShare / 1e12;
        emit Withdraw(msg.sender, _amount);
    }

    // Function to distribute rewards
    function distributeRewards() external payable {
        require(totalStakes > 0, "No stakes to distribute rewards to");
        uint256 reward = msg.value;
        totalRewards += reward;
        accRewardPerShare += reward * 1e12 / totalStakes;
        }

        // Function to update rewards for all stakers
        function updateRewards() internal {
        if (totalStakes == 0) {
        return;
        }
        uint256 reward = address(this).balance - totalRewards;
        if(reward > 0) {
        totalRewards += reward;
        accRewardPerShare += reward * 1e12 / totalStakes;
    }
    }

    // Function for a staker to claim their rewards
    function claimReward() external {
        updateRewards();
        uint256 pending = stakes[msg.sender] * accRewardPerShare / 1e12 - rewardDebt[msg.sender];
        require(pending > 0, "No rewards to claim");
        rewardDebt[msg.sender] = stakes[msg.sender] * accRewardPerShare / 1e12;
        payable(msg.sender).transfer(pending);
        emit ClaimReward(msg.sender, pending);
    }
}