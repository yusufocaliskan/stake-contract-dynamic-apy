// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "hardhat/console.sol";
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
        uint apy;
        uint poolTotalStakedAmount;
        bool isPaused;
        uint256 minStakingAmount;
        uint256 maxStakingLimit;
        uint256 daysOfPool;
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
        uint256 lastStakeRewardTime;

        uint stakeDays;
        uint stakeAmount;
        uint stakeReward;
        uint256 totalReward; //the reward that would be given to the user at the end of the stake time (the pool time)
        uint256 totalRewardWithAmount; 
    }

    uint256 private idCounter;

    mapping( string => mapping ( address => mapping(uint256 => Stakes)) ) private _stakes;
    uint256[] private _allStakeIds;
    mapping(string => mapping(address => uint256[])) private _userPoolStakeIds;



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

        require(_token.balanceOf(address(this)) >= amount, "TStaking--> Insufficient funds in the treasury.");
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

        uint daysOfPool = getStakingDurationInDays(startDate, endDate);
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
            maxStakingLimit: maxStakingLimit,
            daysOfPool:daysOfPool 
        });

        // set it
        _stakePool[stakePoolId] = newPool;
        
        _allStakePools.push(stakePoolId);
        _allStakePoolIds.push(stakePoolId);

        emit StakePoolCreated(stakePoolId, name, startDate, endDate, apy, minStakingAmount, maxStakingLimit);

    }

    function checkStakingConditions(address userAddress, uint256 _amount, string memory _stakePoolId) internal view {
        require(!_stakePool[_stakePoolId].isPaused, "The stake is paused.");
        require(block.timestamp > _stakePool[_stakePoolId].startDate, "Staking not started yet");
        require(_stakePool[_stakePoolId].endDate > block.timestamp, "Staking is ended.");
        require(_users[_stakePoolId][userAddress].totalStakedAmount + _amount <= _stakePool[_stakePoolId].maxStakingLimit, "Max staking token limit reached");
        require(_amount > 0, "Stake amount must be non-zero.");
        require(_amount >= _stakePool[_stakePoolId].minStakingAmount, "Stake Amount must be greater than min. amount allowed.");
    }


    //gets the amount that the users wants 
    function stakeToken(address userAddress, uint256 _amount, string memory _stakePoolId) public nonReentrant{
        
        console.log("---Stake Token---", block.timestamp);
        //Some validations
        checkStakingConditions(userAddress, _amount, _stakePoolId);

        bool isUserExistsInThePool = _users[_stakePoolId][userAddress].account != address(0);
 
        //If the user didn't register for the stake pool
        if(!isUserExistsInThePool)
        {
            _totalUsers +=1;
        }

        //Update the users info
        _users[_stakePoolId][userAddress].totalStakedAmount += _amount;

        //make the transfer
        _token.transferFrom(userAddress, address(this), _amount);

        uint256 stakeId =  generateId();

        uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;
        uint stakeDays = getStakingDurationInDays(block.timestamp, stakePoolEndDate);
        Stakes memory newStake = Stakes({
                stakePoolId:_stakePoolId,
                stakeId: stakeId,
                lastStakeRewardTime: block.timestamp,
                startDate: block.timestamp,
                stakeDays: stakeDays,
                stakeAmount: _amount,
                stakeReward: 0,
                totalReward: 0, 
                totalRewardWithAmount:0
        });
        _stakes[_stakePoolId][userAddress][stakeId] = newStake;

        //calculate the total reward for the current stake
        uint256 totalReward = calculateTotalRewardsOfStake(userAddress, _stakePoolId, stakeId);

        //update it
        _stakes[_stakePoolId][userAddress][stakeId].totalReward =totalReward; 
        _stakes[_stakePoolId][userAddress][stakeId].totalRewardWithAmount =totalReward+_amount; 

        _userPoolStakeIds[_stakePoolId][userAddress].push(stakeId);       _allStakeIds.push(stakeId);

        //Throw an event
        emit Stake(userAddress, _amount);
    }

   
    function calculateCurrentStakeRewardByStakeId(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {
        console.log("calculateCurrentStakeRewardByStakeId");



        uint256 totalRewardWithAmount = _stakes[_stakePoolId][userAddress][_stakeId].totalRewardWithAmount;

        uint256 stakeReward = _stakes[_stakePoolId][userAddress][_stakeId].stakeReward;

        // Fetch stake details
        uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;

        uint256 lastRewardTime = _stakes[_stakePoolId][userAddress][_stakeId].lastStakeRewardTime; 
        uint256 stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
        uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;

        // uint256 stakeDays = getStakingDurationInDays(stakeStartDate, min(lastRewardTime, stakeEndDate));

        uint256 stakeDays = getStakingDurationInDays(lastRewardTime, stakeEndDate );

        // Calculate staking periods in days
        uint256 totalStakeDays = getStakingDurationInDays(stakeStartDate, stakeEndDate);

        // Calculate daily interest and principal return
        uint256 dailyInterest = calculateDailyInterest(stakeAmount, _stakePool[_stakePoolId].apy);
        uint256 dailyPrincipalReturn = stakeAmount / totalStakeDays;

        // Sum up total rewards
        uint256 totalInterestReward = dailyInterest * stakeDays;
        uint256 totalPrincipalReturn = dailyPrincipalReturn * stakeDays;

        // Calculate total reward including principal
        uint256 totalRewardWithPrincipal = totalInterestReward + totalPrincipalReturn;


        // console.log("Staked amount:", stakeAmount);
        console.log("stakeReward == totalRewardWithAmount:", stakeReward == totalRewardWithAmount);
        console.log("totalRewardWithAmount:", totalRewardWithAmount);
        console.log("stakeReward:", stakeReward);
        console.log("Stake days calculated:", stakeDays);
        console.log("Total stake days:", totalStakeDays);
        // console.log("Interest per day:", dailyInterest);
        // console.log("Principal per day:", dailyPrincipalReturn);
        // console.log("Total reward including principal:", totalRewardWithPrincipal);

        return totalRewardWithPrincipal;
    }

    // Utility function to calculate the minimum of two values
    function min(uint256 a, uint256 b) internal pure returns(uint256) {
        return a < b ? a : b;
    }

    // Function to calculate daily interest based on APY and stake amount
    function calculateDailyInterest(uint256 stakeAmount, uint256 apy) internal pure returns(uint256) {
        uint256 dailyRate = (apy * 1e18) / 36500;
        return stakeAmount * dailyRate / 1e20;
    }

    //Total reward of a spesific stake in a pool.
    function calculateTotalRewardsOfStake(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {


        console.log("----calculateTotalRewardsOfStake---" );

        //     // Günlük Faiz Getirisi = (Anapara / 100) x (Faiz Oranı / 365) x Gün Sayısı​ Aylık 
        //     // Faiz Getirisi = (Anapara / 100) x (Faiz Oranı / 12) x Ay Sayısı​ Yıllık Faiz
        //     // Getirisi = (Anapara / 100) x (Faiz Oranı) x Yıl Sayısı​


        // Staked amount
        uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;

        uint stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
        uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;

        // APY of the pool
        uint256 apyRate = _stakePool[_stakePoolId].apy;


        // uint256 daysElapsed = elapsedTime / 86400; // seconds in a day
        uint stakeDays = getStakingDurationInDays(stakeStartDate, stakePoolEndDate); 


        uint256 dailyRate = (apyRate * 1e18) / 36500; 

        uint256 interestPerDay = stakeAmount * dailyRate / 1e20; 
        uint256 totalRewardOfTheStake = interestPerDay * stakeDays;

        return totalRewardOfTheStake;
    }


    function calculateTotalRewardInStakePoolOfUser(address userAddress, string memory _stakePoolId) public returns(uint256){

        uint256[] memory relevantStakeIds = _userPoolStakeIds[_stakePoolId][userAddress];

        uint countStakeOfPool = relevantStakeIds.length;
        uint256 rewardAmount = 0;

        for(uint256 i = 0; i < countStakeOfPool; i++){

            uint256 stakeId = relevantStakeIds[i];
            uint256 rewardOfStake = calculateCurrentStakeRewardByStakeId(userAddress, _stakePoolId, stakeId);

            _stakes[_stakePoolId][userAddress][stakeId].stakeReward = rewardOfStake; 

            rewardAmount += rewardOfStake;
        }
        return rewardAmount;
    }


    function claimReward4Each(address userAddress, string memory _stakePoolId, uint256 _stakeId) public returns(uint256){

        uint256 rewardAmount = 0;

        uint256 rewardOfStake = calculateCurrentStakeRewardByStakeId(userAddress, _stakePoolId, _stakeId);

        _stakes[_stakePoolId][userAddress][_stakeId].stakeReward = rewardOfStake; 

        rewardAmount += rewardOfStake;

        _token.transfer(userAddress, rewardOfStake);

        _stakes[_stakePoolId][userAddress][_stakeId].lastStakeRewardTime = block.timestamp; 

        emit ClaimReward(userAddress, rewardAmount);
        return rewardAmount;
    }

    function claimReward4Total(address userAddress, string memory _stakePoolId) public returns(uint256){

        uint256[] memory relevantStakeIds = _userPoolStakeIds[_stakePoolId][userAddress];

        uint countStakeOfPool = relevantStakeIds.length;

        uint256 rewardAmount = 0;

        for(uint256 i = 0; i < countStakeOfPool; i++){

            uint256 stakeId = relevantStakeIds[i];
            uint256 rewardOfStake = calculateCurrentStakeRewardByStakeId(userAddress, _stakePoolId, stakeId);
            console.log("rewardOfStake",rewardOfStake);

            _stakes[_stakePoolId][userAddress][stakeId].stakeReward = rewardOfStake; 

            rewardAmount += rewardOfStake;

            uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;

            //Update last stake time
            if (block.timestamp < stakeEndDate) {
                _stakes[_stakePoolId][userAddress][stakeId].lastStakeRewardTime = block.timestamp;
            } else {
                _stakes[_stakePoolId][userAddress][stakeId].lastStakeRewardTime = stakeEndDate;
            }
        }

        require(rewardAmount > 0,"No token to claim" );
        _token.transfer(userAddress, rewardAmount);



        console.log("Total Reward:", rewardAmount);
        emit ClaimReward(userAddress, rewardAmount);
        return rewardAmount;
    }
    function getTotalRewardsInThePoolOfUser(address userAddress, string memory _stakePoolId) public view returns(uint256){

        uint256[] memory relevantStakeIds = _userPoolStakeIds[_stakePoolId][userAddress];

        uint countStakeOfPool = relevantStakeIds.length;

        uint256 rewardAmount = 0;

        for(uint256 i = 0; i < countStakeOfPool; i++){

            uint256 stakeId = relevantStakeIds[i];
            uint256 rewardOfStake = calculateCurrentStakeRewardByStakeId(userAddress, _stakePoolId, stakeId);
            console.log("rewardOfStake",rewardOfStake);
            rewardAmount += rewardOfStake;
        }

        return rewardAmount;
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

    //Enabling or disabling the staking
    function toggleStakingStatus(string memory _stakePoolId) external onlyOwner{
         _stakePool[_stakePoolId].isPaused = !_stakePool[_stakePoolId].isPaused;
    }

    
    function getWithdrawableAmountOfContract() external view returns(uint256){
        return _token.balanceOf(address(this)) - _totalStakedTokensOfContract;
    }


    function getStakingDurationInDays(uint256 _startTimestamp, uint256 _endTimestamp) public pure returns (uint256) {
        uint256 durationInSeconds = _endTimestamp - _startTimestamp;
        uint256 durationInDays = durationInSeconds / 60 / 60 / 24;
        return durationInDays;
    }


    function generateId() public returns (uint256) {
           idCounter++;
            return idCounter;
    }
    
}