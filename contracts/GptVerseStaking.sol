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
        
        console.log("---Stake Token---");
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
                // startDate: testStakeDate,
                lastStakeRewardTime: 0,
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

        console.log("totalReward--- Heree", totalReward);
        //update it
        _stakes[_stakePoolId][userAddress][stakeId].totalReward =totalReward; 
        _stakes[_stakePoolId][userAddress][stakeId].totalRewardWithAmount =totalReward+_amount; 

        _allStakeIds.push(stakeId);

        //Throw an event
        emit Stake(userAddress, _amount);
    }

   

    //Total reward of a spesific stake in a pool.
    function calculateTotalRewardsOfStake(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {


        console.log("----calculateTotalRewardsOfStake---" );

        //     // Günlük Faiz Getirisi = (Anapara / 100) x (Faiz Oranı / 365) x Gün Sayısı​ Aylık 
        //     // Faiz Getirisi = (Anapara / 100) x (Faiz Oranı / 12) x Ay Sayısı​ Yıllık Faiz
        //     // Getirisi = (Anapara / 100) x (Faiz Oranı) x Yıl Sayısı​


        // Staked amount
        uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;

        // Start and end dates of the stake
        // uint _stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
        // uint _stakeEndDate = _stakes[_stakePoolId][userAddress][_stakeId].endDate;

        uint stakePoolStartDate = _stakePool[_stakePoolId].startDate;
        uint stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
        uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;


        // APY of the pool

        uint256 apyRate = _stakePool[_stakePoolId].apy;

        uint256 elapsedTime = stakePoolEndDate - stakeStartDate;

        // uint256 daysElapsed = elapsedTime / 86400; // seconds in a day
        uint stakeDays = getStakingDurationInDays(stakeStartDate, stakePoolEndDate); 
        uint totalStakePoolDays = getStakingDurationInDays(stakePoolStartDate, stakePoolEndDate); 


        uint256 dailyRate = (apyRate * 1e18) / 36500; 

        uint256 interestPerDay = stakeAmount * dailyRate / 1e20; 
        uint256 totalRewardOfTheStake = interestPerDay * stakeDays;


        console.log("amount --->", stakeAmount);
        console.log("apy --->", apyRate);
        console.log("elapsedTime --->", elapsedTime);
        console.log("totalStakePoolDays --->", totalStakePoolDays);
        console.log("_stakeDays --->", stakeDays);
        console.log("dailyRate --->", dailyRate);
        console.log("totalRewardOfTheStake --->", totalRewardOfTheStake);

        return totalRewardOfTheStake;
    }

    //current reward of a spesific stake in a pool.
    // Current reward of a specific stake in a pool.
function calculateCurrentStakeRewardByStakeId(address userAddress, string memory _stakePoolId, uint256 _stakeId) public view returns(uint256) {
    console.log("calculateCurrentStakeRewardByStakeId");

    // Staked amount
    uint256 stakeAmount = _stakes[_stakePoolId][userAddress][_stakeId].stakeAmount;

    uint256 currentTime = block.timestamp;
    uint256 lastStakeRewardTime = _stakes[_stakePoolId][userAddress][_stakeId].lastStakeRewardTime;
    uint256 stakeStartDate = _stakes[_stakePoolId][userAddress][_stakeId].startDate;
    uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;

    // Calculate the number of days from stake start to the minimum of current time or stake end time
    uint256 effectiveStakeTime = (lastStakeRewardTime == 0) ? currentTime : lastStakeRewardTime;
    uint256 stakeDays = getStakingDurationInDays(stakeStartDate, (effectiveStakeTime > stakeEndDate ? stakeEndDate : effectiveStakeTime));

    uint256 totalStakeDays = getStakingDurationInDays(stakeStartDate, stakeEndDate);
    uint256 dailyRate = (_stakePool[_stakePoolId].apy * 1e18) / 36500;
    uint256 interestPerDay = stakeAmount * dailyRate / 1e20;

    uint256 principalPerDay = stakeAmount / totalStakeDays;

    uint256 totalInterestReward = interestPerDay * stakeDays;
    uint256 totalPrincipalReturn = principalPerDay * stakeDays;

    uint256 totalRewardWithPrincipal = totalInterestReward + totalPrincipalReturn;

    console.log("Staked amount:", stakeAmount);
    console.log("Stake days calculated:", stakeDays);
    console.log("Total stake days:", totalStakeDays);
    console.log("Interest per day:", interestPerDay);
    console.log("Principal per day:", principalPerDay);
    console.log("Total reward including principal:", totalRewardWithPrincipal);

    return totalRewardWithPrincipal;
}


    function claimReward(address userAddress, string memory _stakePoolId, uint256 _stakeId) public  returns(uint256){

        console.log("----Claim Token---");
        // _calculateRewards(userAddress, _stakePoolId);
        uint256 rewardAmount = calculateCurrentStakeRewardByStakeId(userAddress, _stakePoolId, _stakeId);


        console.log("Claim Token --> rewardAmount", rewardAmount);
        _token.transfer(userAddress, rewardAmount);

         _stakes[_stakePoolId][userAddress][_stakeId].lastStakeRewardTime = block.timestamp;
         _stakes[_stakePoolId][userAddress][_stakeId].stakeReward = rewardAmount;


        emit ClaimReward(userAddress, rewardAmount);
        return rewardAmount;
    }

    function isStakePoolEnded(string memory _stakePoolId) public view returns (bool) {
        uint _stakePoolStartDate = _stakePool[_stakePoolId].startDate;
        uint _stakePoolEndDate = _stakePool[_stakePoolId].endDate;
        uint currentTime = block.timestamp;

        uint elapsedTime = _stakePoolEndDate - _stakePoolStartDate; 
        uint256 totalDays = elapsedTime / (60 * 60 * 24); 

        console.log("Total Pool Duration (Days):", totalDays);
        console.log("Current Time:", currentTime);
        console.log("Pool End Time:", _stakePoolEndDate);

        // Check if the current time is past the pool's end time
        return currentTime > _stakePoolEndDate;
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
        uint256 durationInSeconds = _endTimestamp - _startTimestamp;
        uint256 durationInDays = durationInSeconds / 60 / 60 / 24;
        return durationInDays;
    }

    function generateId() public returns (uint256) {
           idCounter++;
            return idCounter;
    }
    
}