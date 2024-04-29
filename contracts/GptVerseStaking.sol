// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract GptVerseStaking is Initializable, ReentrancyGuard, Ownable{


    struct StakePools{
        string stakePoolId;
        string name;
        uint startDate;
        uint endDate;
        uint apy;
        uint poolTotalStakedAmount;
        bool isPaused;
        uint256 minStakingAmount;
        uint256 maxStakingLimit;
    }

    uint256 _totalPools;

    // listining
    string[] private _allStakePools;
    string[] private _allStakePoolIds;


    //Stake Pool
    mapping(string=>StakePools) private _stakePool;

    // Stakes holder
    struct Stakes{
        string stakePoolId;
        uint256 stakeId;
        uint startDate;
        uint stakeAmount;
        uint stakeReward;
    }

    uint256 private idCounter;

    mapping( string => mapping ( address => mapping(uint256 => Stakes)) ) private _stakes;
    uint256[] private _allStakeIds;


    //the user
    struct User{
        address account;
        uint256 rewardAmount;
        uint256 lastStakeTime;
        uint256 lastRewardCalculationTime;
        uint256 rewardClaimedSoFar;
        uint256 totalStakedAmount;
    }

    uint256 _totalUsers;
    string[] private _allUserIds;

    //User mapping

    mapping( string => mapping ( address => User) ) private _users;


    IERC20 private _token;


    //Total stakes
    // uint256 _totalStakedTokens;
    uint256 _totalStakedTokensOfContract;
    

    //Address of the Staking 
    address private _tokenAddress;


    //================== EVENTS ========================

    event Stake(address indexed user, uint256 amount); // when staking
    event UnStake(address indexed user, uint256 amount); // when unstaking
    event EarlyUnStakeFee(address indexed user, uint256 amount); // when early staking
    event ClaimReward(address indexed user, uint256 amount); //when clamin the reward
    event StakePoolCreated(string indexed stakePoolId, string name, uint startDate, uint endDate, uint apy, uint256 minStakingAmount, uint256 maxStakingLimit);



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
        uint256 minStakingAmount,
        uint256 maxStakingLimit) public onlyOwner{
            require(apy <= 10000, "TStaking--> APY rate should be less then 10000");

            require(startDate < endDate, "TStaking--> Start date connot be greater than the end date");

        // Create a new stake pool
        StakePools memory newPool = StakePools({
            stakePoolId: stakePoolId,
            name: name,
            startDate: startDate,
            endDate: endDate,
            apy: apy,
            poolTotalStakedAmount: 0,
            isPaused: false,
            minStakingAmount: minStakingAmount,
            maxStakingLimit: maxStakingLimit
        });

        // set it
        _stakePool[stakePoolId] = newPool;
        
        _allStakePools.push(stakePoolId);
        _allStakePoolIds.push(stakePoolId);

        emit StakePoolCreated(stakePoolId, name, startDate, endDate, apy, minStakingAmount, maxStakingLimit);

    }

    //gets the amount that the users wants 
    function stakeToken(address userAddress, uint256 _amount, string memory _stakePoolId) external nonReentrant{
        
        bool _isStakingPaused = _stakePool[_stakePoolId].isPaused; 
        uint _stakeStartDate = _stakePool[_stakePoolId].startDate; 
        uint _stakeEndDate = _stakePool[_stakePoolId].endDate; 
        uint _maxStakingLimit = _stakePool[_stakePoolId].maxStakingLimit; 
        uint _minStakingAmount = _stakePool[_stakePoolId].minStakingAmount; 
        uint _totalStakedAmount = _users[_stakePoolId][userAddress].totalStakedAmount; 
        // uint _lastRewardCalculationTime = _users[_stakePoolId][userAddress].lastRewardCalculationTime; 
        bool isUserExistsInThePool = _users[_stakePoolId][userAddress].account != address(0);
 

        //is the staking paused?
        require(!_isStakingPaused,"The stake is paused.");

        //Check for the time
        uint256 currentTime = block.timestamp;

        require(currentTime > _stakeStartDate, "Staking not started yet");
        require(_stakeEndDate > currentTime , "Staking is ended.");

        //Check for the amounts
        require(_totalStakedAmount + _amount <= _maxStakingLimit, "Max staking token limit reached ${_maxStakingLimit}");

        require(_amount > 0, "Stake amount must be non-zero.");

        require( _amount >= _minStakingAmount, "Stake Amount must be greater than min. amount allowed.");

        //If the user didn't register for the stake pool
        if(!isUserExistsInThePool)
        {
            _totalUsers +=1;
        }

        //Update the users info
        _users[_stakePoolId][userAddress].totalStakedAmount += _amount;
        _users[_stakePoolId][userAddress].lastStakeTime += currentTime;

        //make the transfer
        _token.transferFrom(userAddress, address(this), _amount);

        uint256 stakeId =  generateId();

        Stakes memory newStake = Stakes({
                stakePoolId:_stakePoolId,
                stakeId: stakeId,
                startDate:block.timestamp,
                stakeAmount: _amount,
                stakeReward: 0
            });

        _stakes[_stakePoolId][userAddress][stakeId] = newStake;
        _allStakeIds.push(stakeId);
        //Throw an event
        emit Stake(userAddress, _amount);
    }

    // function _calculateRewards(address userAddress, string memory _stakePoolId) private {

    //     (uint256 userReward, uint256 currentTime) = calculateUserEstimatedRewards(userAddress, _stakePoolId);

    //     _users[_stakePoolId][userAddress].rewardAmount += userReward;

    //     // Corrected the assignment
    //     _users[_stakePoolId][userAddress].lastRewardCalculationTime = currentTime; 
    // }

    function calculateUserEstimatedRewards(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {

        uint256 userReward;

        uint _stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;

        uint _stakePoolStartDate = _stakePool[_stakePoolId].startDate;
        uint _stakePoolEndDate = _stakePool[_stakePoolId].endDate;


        uint _apyRate = _stakePool[_stakePoolId].apy;  

        // uint _stakeDays = _stakePool[_stakePoolId].stakeDays;
        uint _lastStakeTime = _stakes[_stakePoolId][userAddress][_stakeId].startDate;

        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - _lastStakeTime;
        uint _stakeDays = getStakingDurationInDays(_stakePoolStartDate, _stakePoolEndDate); 

        // Prevent overflow
        if (currentTime > _lastStakeTime + _stakeDays * 1 days) {
            currentTime = _lastStakeTime + _stakeDays * 1 days;
        }

        elapsedTime = currentTime - _lastStakeTime;
        console.log("elapsedTime: ", elapsedTime);
        // Elapsed time converted to days
        uint256 daysStaked = elapsedTime / 60 / 60 / 24;
        console.log("daysStaked: ", daysStaked);
        uint dailyRate = calculateDailyAPY(_apyRate);
        console.log("dailyRate: ", dailyRate);
        userReward = (_stakeAmount * dailyRate / 100) * daysStaked;  
        console.log("userReward : ", userReward);

        return userReward;
    }



    function getAllStakePools() public view returns (StakePools[] memory) {
        uint length = _allStakePoolIds.length;
        StakePools[] memory pools = new StakePools[](length);
        for (uint i = 0; i < length; i++) {
            string memory poolId = _allStakePools[i];
            pools[i] = _stakePool[poolId];
        }
        return pools;
    }

    function getStakePoolById(string memory _stakePoolId)public view returns(StakePools memory){
        return _stakePool[_stakePoolId];
    }

    function getAllUserStakesByStakePoolsId(string memory _stakePoolId, address _userAddress) public view returns (Stakes[] memory) {
        uint length = _allStakeIds.length;
        Stakes[] memory stakes = new Stakes[](length);
        for (uint i = 0; i < length; i++) {
            uint256 poolId = _allStakeIds[i];
            stakes[i] = _stakes[_stakePoolId][_userAddress][poolId];
        }
        return stakes;
    }

    function getStakeById(string memory _stakePoolId, address _userAddress, uint256 _stakeId)public view returns(Stakes memory){

        return _stakes[_stakePoolId][_userAddress][_stakeId];
    }

    //================== SETTERS ========================
    // ---- those functions  that could be used by the owner ----

    //Enabling or disabling the staking
    function toggleStakingStatus(string memory _stakePoolId) external onlyOwner{
         _stakePool[_stakePoolId].isPaused = !_stakePool[_stakePoolId].isPaused;
    }

 //================== SOME UTILS  ========================
    
    function calculateDailyAPY(uint _apy) public pure returns (uint) {
        return (_apy * 100000) / 3650000;
    }

    function claimReward(address userAddress, string memory _stakePoolId, uint256 _stakeId) external nonReentrant whenTreasuryHasBalance(_users[_stakePoolId][userAddress].rewardAmount) {

        // _calculateRewards(userAddress, _stakePoolId);
        uint rewardAmount = calculateUserEstimatedRewards(userAddress, _stakePoolId, _stakeId);
        require(rewardAmount >0,"No reward to claim");


        _token.transfer(userAddress, rewardAmount);

        emit ClaimReward(userAddress, rewardAmount);
    }

    //================== GETTERS ========================

    //Is the given user address is a stake holder?
    function isUserAStakeHoler(address userAddress, string memory _stakePoolId) external view returns(bool){
        return _users[_stakePoolId][userAddress].account == address(0);
    }


    //Displayes user's estimated rewards
    // function getUserEstimatedRewards(address userAddress, string memory _stakePoolId, bytes32 _stakeId) external view returns(uint256){

    //     //calcs this estimated reward
    //     uint amount = calculateUserEstimatedRewards(userAddress, _stakePoolId, _stakeId) ;

    //     return _users[_stakePoolId][userAddress].rewardAmount + amount;
    // }

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

    function generateId() public returns (uint256) {
           idCounter++;
            return idCounter;
    }
    
}