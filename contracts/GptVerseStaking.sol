// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GptVerseStaking is Initializable, ReentrancyGuard, Ownable{


    struct StakePools{
        string stakePoolId;
        string name;
        uint startDate;
        uint endDate;
        uint stakeDays;
        uint apy;
        uint totalStakedTokens;
        uint earlyUnStakeFeePercentage;
        bool isPaused;
        uint256 minStakingAmount;
        uint256 maxStakingLimit;
    }

    uint256 _totalPools;

    // listining
    string[] private _allStakePools;

    //Stake Pool
    mapping(string=>StakePools) private _stakePool;



    //the user
    struct User{
        address account;
        uint256 stakeAmount;
        uint256 rewardAmount;
        uint256 lastStakeTime;
        uint256 lastRewardCalculationTime;
        uint256 rewardClaimedSoFar;
        uint256 totalStakedTokens;
    }

    uint256 _totalUsers;
    //User mapping

    mapping( string => mapping ( address => User) ) private _users;


    IERC20 private _token;


    //Total stakes
    // uint256 _totalStakedTokens;
    uint256 _totalStakedTokensOfContract;
    

    //Address of the Staking 
    address private _tokenAddress;


    uint256 public constant PERCENTAGE_DENOMINATOR = 10000;
    uint256 public constant APY_RATE_CHANGE_THRESHOLD = 10;


    //================== EVENTS ========================

    event Stake(address indexed user, uint256 amount); // when staking
    event UnStake(address indexed user, uint256 amount); // when unstaking
    event EarlyUnStakeFee(address indexed user, uint256 amount); // when early staking
    event ClaimReward(address indexed user, uint256 amount); //when clamin the reward


    //================== MODIFIERS ========================

    //Chekcs if the address has enought balance
    modifier whenTreasuryHasBalance(uint256 amount){

        require(IERC20(_tokenAddress).balanceOf(address(this)) >= amount, "TStaking--> Insufficient funds in the treasury.");
        _;
    }


    //Initializer
    constructor( address initialOwner, address tokenAddress_) Ownable(initialOwner) 
        {

            _token = IERC20(tokenAddress_);
            _tokenAddress = tokenAddress_;
    }


    //Creates new Stake pool
    function createStakePool(string memory stakePoolId,
        string memory name,
        uint startDate,
        uint endDate,
        uint apy,
        uint totalStakedTokens,
        uint earlyUnStakeFeePercentage,
        uint256 minStakingAmount,
        uint256 maxStakingLimit) public onlyOwner{
            require(apy <= 10000, "TStaking--> APY rate should be less then 10000");

            require(startDate < endDate, "TStaking--> Start date connot be greater than the end date");

        _stakePool[stakePoolId] = StakePools(
             stakePoolId,
             name,
             startDate,
             endDate,
             getStakingDurationInDays(startDate, endDate),
             apy,
             totalStakedTokens,
             earlyUnStakeFeePercentage,
             false,
             minStakingAmount,
             maxStakingLimit
        );
        _allStakePools.push(stakePoolId);
    }

    //gets the amount that the users wants 
    function stakeToken(address userAddress, uint256 _amount, string memory _stakePoolId) external nonReentrant onlyOwner{
        
        bool _isStakingPaused = _stakePool[_stakePoolId].isPaused; 
        uint _stakeStartDate = _stakePool[_stakePoolId].startDate; 
        uint _stakeEndDate = _stakePool[_stakePoolId].endDate; 
        uint _maxStakingLimit = _stakePool[_stakePoolId].maxStakingLimit; 
        uint _minStakingAmount = _stakePool[_stakePoolId].minStakingAmount; 
        uint _stakeAmount = _users[_stakePoolId][userAddress].stakeAmount; 
        uint _lastRewardCalculationTime = _users[_stakePoolId][userAddress].lastRewardCalculationTime; 
        bool isUserExistsInThePool = _users[_stakePoolId][userAddress].account != address(0);
 

        //is the staking paused?
        require(!_isStakingPaused,"The stake is paused.");

        //Check for the time
        uint256 currentTime = block.timestamp;

        require(currentTime > _stakeStartDate, "Staking not started yet");
        require(currentTime < _stakeEndDate, "Staking is ended.");

        //Check for the amounts
        require(_stakeAmount + _amount <= _maxStakingLimit, "Max staking token limit reached ${_maxStakingLimit}");

        require(_amount > 0, "Stake amount must be non-zero.");

        require( _amount >= _minStakingAmount, "Stake Amount must be greater than min. amount allowed.");

        // Calculate the users reward for the next  
        if(_stakeAmount != 0){
            //Then calc it
            _calculateRewards(userAddress, _stakePoolId);
        }else{
            _lastRewardCalculationTime = currentTime;

            //If the user didn't register for the stake pool
            if(!isUserExistsInThePool)
            {
                _totalUsers +=1;
            }
        }


        //Update the users info
        _users[_stakePoolId][userAddress].stakeAmount += _amount;
        _users[_stakePoolId][userAddress].lastStakeTime += currentTime;

        //make the transfer
        _token.transferFrom(userAddress, address(this), _amount);

        //Throw an event
        emit Stake(userAddress, _amount);
    }

    function _calculateRewards(address userAddress, string memory _stakePoolId) private {

        (uint256 userReward, uint256 currentTime) = _getUserEstimatedRewards(userAddress, _stakePoolId);

        _users[_stakePoolId][userAddress].rewardAmount += userReward;

        // Corrected the assignment
        _users[_stakePoolId][userAddress].lastRewardCalculationTime = currentTime; 
    }

    function _getUserEstimatedRewards(address userAddress, string memory _stakePoolId) private view  returns(uint256, uint256){

        uint256 userReward;
        uint256 userTimestamp = _users[_stakePoolId][userAddress].lastRewardCalculationTime;
        uint _userStakeAmount = _users[_stakePoolId][userAddress].stakeAmount;
        uint _apyRate = _stakePool[_stakePoolId].apy;
        uint _stakeDays = _stakePool[_stakePoolId].stakeDays;

        uint256 currentTime = block.timestamp;

        if(currentTime > _users[_stakePoolId][userAddress].lastStakeTime + _stakeDays){

            currentTime = _users[_stakePoolId][userAddress].lastStakeTime + _stakeDays;
        }

        uint256 totalStakedTime = currentTime - userTimestamp;

        userReward += ((totalStakedTime * _userStakeAmount * _apyRate) / 365 days) / PERCENTAGE_DENOMINATOR;

        return (userReward, currentTime);

    }
    
     
    //================== SETTERS ========================
    // ---- those functions  that could be used by the owner ----

    //Enabling or disabling the staking
    function toggleStakingStatus(string memory _stakePoolId) external onlyOwner{
         _stakePool[_stakePoolId].isPaused = !_stakePool[_stakePoolId].isPaused;
    }

 //================== SOME UTILS  ========================
    
 
    function claimReward(address userAddress, string memory _stakePoolId) external nonReentrant whenTreasuryHasBalance(_users[_stakePoolId][userAddress].rewardAmount) {

        _calculateRewards(userAddress, _stakePoolId);

        uint256 rewardAmount = _users[_stakePoolId][userAddress].rewardAmount;


        require(rewardAmount >0,"No reward to claim");

        IERC20(_tokenAddress).transfer(msg.sender, rewardAmount);

        _users[_stakePoolId][userAddress].rewardAmount = 0;
        _users[_stakePoolId][userAddress].rewardClaimedSoFar -= rewardAmount;

        emit ClaimReward(userAddress, rewardAmount);
    }

    //================== GETTERS ========================

    //Is the given user address is a stake holder?
    function isUserAStakeHoler(address userAddress, string memory _stakePoolId) external view returns(bool){
        return _users[_stakePoolId][userAddress].account == address(0);
    }


    //Displayes user's estimated rewards
    function getUserEstimatedRewards(address userAddress, string memory _stakePoolId) external view returns(uint256){

        //calcs this estimated reward
        (uint256 amount,) = _getUserEstimatedRewards(userAddress, _stakePoolId) ;

        return _users[_stakePoolId][userAddress].rewardAmount + amount;
    }

    function getWithdrawableAmountOfContract() external view returns(uint256){
        return _token.balanceOf(address(this)) - _totalStakedTokensOfContract;
    }


    //Return user's details by given address 
    function getUserDetails(address userAddress, string memory _stakePoolId) external view returns(User memory){
        return _users[_stakePoolId][userAddress];
    }


    function getStakingDurationInDays(uint256 _startTimestamp, uint256 _endTimestamp) public pure returns (uint256) {
        require(_endTimestamp > _startTimestamp, "End date must be after start date");
        uint256 durationInSeconds = _endTimestamp - _startTimestamp;
        uint256 durationInDays = durationInSeconds / 60 / 60 / 24;
        return durationInDays;
    }
    
}