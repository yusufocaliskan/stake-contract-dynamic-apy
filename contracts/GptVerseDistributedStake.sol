// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol"; 

import "hardhat/console.sol";

contract GptVerseDistributedStake is ReentrancyGuardUpgradeable, OwnableUpgradeable, UUPSUpgradeable{

    string public constant VERSION= "1.0";

    struct StakePools{
        string stakePoolId;
        string name;
        uint startDate;
        uint endDate;
        uint totalStakedAmountOfPool;
        bool isPaused;
        uint256 minStakingAmount;
        uint256 maxStakingLimit;
        bool isDeleted;
        uint256 allocatedAmount;
        uint minAPY;
        uint maxAPY;
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
        uint stakeAmount;
        address userAddress; 
    }

    uint256 private idCounter;

    mapping( string => mapping ( address => mapping(uint256 => Stakes)) ) private _stakes;

    uint256[] private _allStakeIds;

    mapping(string => mapping(address => uint256[])) private _userPoolStakeIds;

    mapping(string => Stakes[]) private _stakesInPool;


    //the user
    struct User{
        address account;
        uint256 totalStakedAmount;
        uint256 totalClaimedRewards;
    }

    uint256 _totalUsers;
    string[] private _allUserIds;

    //User mapping

    mapping( string => mapping ( address => User) ) private _users;

    IERC20 private _token;

    //Address of the Staking 
    address private _tokenAddress;

    //================== EVENTS ========================

    event Stake(address indexed user, uint256 amount); // when staking
    event ClaimReward(address indexed user, uint256 amount); //when clamin the reward

    event StakePoolCreated(string indexed stakePoolId, string name, uint startDate, uint endDate,  uint256 minStakingAmount, uint256 maxStakingLimit, uint256 allocatedAmount);

    event StakePoolUpdated(string indexed stakePoolId, string name, uint startDate, uint endDate,  uint256 minStakingAmount, uint256 maxStakingLimit);

    //================== MODIFIERS ========================

    //Chekcs if the address has enought balance
    modifier whenTreasuryHasBalance(uint256 amount){
        require(_token.balanceOf(address(this)) >= amount, "Insufficient funds in the treasury.");
        _;
    }

    function setTokenAddress(address tokenAddress_) public  onlyOwner{
        _tokenAddress = tokenAddress_;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function initialize(address initialOwner, address tokenAddress_) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _token = IERC20(tokenAddress_);
        _tokenAddress = tokenAddress_;
    }


    //Creates new Stake pool
    function createStakePool(
        string memory stakePoolId,
        string memory name,
        uint startDate,
        uint endDate,
        uint256 minStakingAmount,
        uint256 maxStakingLimit,
        uint256 allocatedAmount, 
        uint minAPY, 
        uint maxAPY) public onlyOwner{

        bool isPoolExists = bytes(_stakePool[stakePoolId].stakePoolId).length != 0;

        require(maxAPY <= 10000, "Max APY rate should be less then 10000");

        require(minAPY > 0 && minAPY < maxAPY, "Min APY rate should be less then Max APY and greater than 0");

        require(startDate < endDate, "Start date connot be greater than the end date");

        require(!isPoolExists, "The pool has already been created.");

        // Create a new stake pool
        StakePools memory newPool = StakePools({
            stakePoolId: stakePoolId,
            name: name,
            startDate: startDate,
            endDate: endDate,
            totalStakedAmountOfPool: allocatedAmount,
            isPaused: false,
            minStakingAmount: minStakingAmount,
            maxStakingLimit: maxStakingLimit,
            isDeleted: false,
            allocatedAmount:allocatedAmount, 
            minAPY: minAPY,
            maxAPY: maxAPY
        });


        // set it
        _stakePool[stakePoolId] = newPool;
        
        _allStakePools.push(stakePoolId);
        _allStakePoolIds.push(stakePoolId);

        _token.transferFrom(msg.sender, address(this), allocatedAmount);

        emit StakePoolCreated(stakePoolId, name, startDate, endDate,  minStakingAmount, maxStakingLimit, allocatedAmount);

    }

    function checkStakingConditions(uint256 _amount, string memory _stakePoolId) internal view {


        require(_stakePool[_stakePoolId].isDeleted == false, "The pool has been deleted.");
        require(_amount > 0, "Stake amount must be non-zero.");
        require(!_stakePool[_stakePoolId].isPaused, "The stake is paused.");


        //accepts staking before start
        require(!isStakePoolStarted(_stakePoolId), "The pool no longer accepts staking. It has already started.");

        require(!isStakePoolEnded(_stakePoolId), "Staking is ended.");

        require(_amount <= _stakePool[_stakePoolId].maxStakingLimit, "Max staking token limit reached");

        require(_amount >= _stakePool[_stakePoolId].minStakingAmount, "Stake Amount must be greater than min. amount allowed.");
    }


    //gets the amount that the users wants 
    function stakeToken(address userAddress, uint256 _amount, string memory _stakePoolId) public nonReentrant {
        
        //Some validations
        checkStakingConditions(_amount, _stakePoolId);

        bool isUserExistsInThePool = _users[_stakePoolId][userAddress].account != address(0);
 
        //If the user didn't register for the stake pool
        if(!isUserExistsInThePool)
        {
            _totalUsers +=1;
        }

        uint256 stakeId =  generateId();

        // uint stakePoolEndDate = _stakePool[_stakePoolId].endDate;
        Stakes memory newStake = Stakes({
                stakePoolId:_stakePoolId,
                stakeId: stakeId,
                lastStakeRewardTime: block.timestamp,
                startDate: block.timestamp,
                stakeAmount: _amount,
                userAddress: userAddress 
        });

        _stakes[_stakePoolId][userAddress][stakeId] = newStake;

        //Update the users info
        _users[_stakePoolId][userAddress].totalStakedAmount += _amount;

        // update totalStaked Amount
        _stakePool[_stakePoolId].totalStakedAmountOfPool += _amount;

        _userPoolStakeIds[_stakePoolId][userAddress].push(stakeId);       _allStakeIds.push(stakeId);

        _stakesInPool[_stakePoolId].push(newStake);

        //make the transfer
        _token.transferFrom(userAddress, address(this), _amount);


        //Throw an event
        emit Stake(userAddress, _amount);
    }

    // Function to calculate daily interest based on APY and stake amount
    function calculateDailyInterest(uint256 stakeAmount, uint256 apy) internal pure returns(uint256) {
        uint256 dailyRate = (apy * 1e18) / 36500;
        return stakeAmount * dailyRate / 1e20;
    }


    //Check if the pool is started
    function isStakePoolStarted(string memory _stakePoolId) internal view returns (bool){

        uint stakePoolStartDate = _stakePool[_stakePoolId].startDate;
        if(block.timestamp > stakePoolStartDate ){
            return true;
        }

        return false;
    }

    function isStakePoolEnded(string memory _stakePoolId) internal view returns(bool){
        uint stakeEndDate = _stakePool[_stakePoolId].endDate;
        if(  block.timestamp > stakeEndDate){
            return true;
        }
        return false;
    }


    function calculateReward( string memory _stakePoolId,  uint256 _usersTotalStakeAmountInPool) public view returns(uint256) {
        
        uint256 stakeEndDate = _stakePool[_stakePoolId].endDate;
        uint256 stakeStartDate = _stakePool[_stakePoolId].startDate;

        uint256 durationInSeconds = getStakingDurationInSeconds(stakeStartDate, block.timestamp < stakeEndDate ? block.timestamp : stakeEndDate);

        uint256 apyRate = calculateApyRate(_stakePoolId, _usersTotalStakeAmountInPool);

        uint256 perSecondInterest = calculatePerSecondInterest(_usersTotalStakeAmountInPool, apyRate);

        uint256 totalInterestReward = perSecondInterest * durationInSeconds;
        console.log("---totalInterestReward---", totalInterestReward);

        return totalInterestReward;
    }

    //Calculate Dynamic APY Based on user staked token in pool and total staked amount of pool
    function calculateApyRate(string memory _stakePoolId, uint256 _stakedAmount) internal view returns(uint) {
        uint maxAPY = _stakePool[_stakePoolId].maxAPY;
        uint minAPY = _stakePool[_stakePoolId].minAPY;
        uint totalStakedAmountOfPool = _stakePool[_stakePoolId].totalStakedAmountOfPool;
        
        uint256 scaledMaxAPY = maxAPY * 1e18; 
        console.log("scaledMaxAPY", scaledMaxAPY);
        console.log("totalStakedAmountOfPool", totalStakedAmountOfPool);

        console.log("(scaledMaxAPY * _stakedAmount)", (scaledMaxAPY * _stakedAmount));
        console.log("(totalStakedAmountOfPool-_stakedAmount)", (totalStakedAmountOfPool-_stakedAmount));
        uint256 apy = (scaledMaxAPY * _stakedAmount) / (totalStakedAmountOfPool-_stakedAmount);

        uint result = apy / 1e18;
        
        console.log("Result APY", result);

        return result > minAPY ? result : minAPY;

    }



    //claim total rewards of te usr's  stakes 
    //with staked amount
    function claimReward4Total(address userAddress, string memory _stakePoolId) public returns(uint256){


        require(block.timestamp > _stakePool[_stakePoolId].endDate, "Stake Pool has not ended yet.");

        uint256 usersTotalStakeAmountInPool = _users[_stakePoolId][userAddress].totalStakedAmount;

        uint256 totalReward= getCurrentRewards(userAddress, _stakePoolId);
        uint256 resultAmount = totalReward+usersTotalStakeAmountInPool; 

        console.log("---rewardAmount--", totalReward);
        console.log("---resultAmount--", resultAmount);

        require(resultAmount > 0,"No token to claim" );
        _token.transfer(userAddress, resultAmount);

        emit ClaimReward(userAddress, resultAmount);
        return resultAmount;
    }

    //total rewards of te usr's  stakes 
    function getCurrentRewards(address userAddress, string memory _stakePoolId) public view returns(uint256){

        uint256 usersTotalStakeAmountInPool = _users[_stakePoolId][userAddress].totalStakedAmount;

        uint256 totalReward = calculateReward( _stakePoolId, usersTotalStakeAmountInPool);
        return totalReward;
    }

    
    // Function to calculate per-second interest
    function calculatePerSecondInterest(uint256 stakeAmount, uint256 apy) internal pure returns (uint256) {
        uint256 annualInterest = stakeAmount * apy / 10000; 
        return annualInterest / (365 * 24 * 3600); 
    }

    function getStakingDurationInSeconds(uint256 _startTimestamp, uint256 _endTimestamp) public pure returns (uint256) {
        return _endTimestamp - _startTimestamp;
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

    function getAllUserStakesByStakePoolsId(string memory _stakePoolId, address _userAddress) public onlyOwner view returns (Stakes[] memory) {
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
    function toggleStakingStatus(string memory _stakePoolId) public onlyOwner{
         _stakePool[_stakePoolId].isPaused = !_stakePool[_stakePoolId].isPaused;
    }

    function setIsDeleted(string memory _stakePoolId) public onlyOwner{
         _stakePool[_stakePoolId].isDeleted = !_stakePool[_stakePoolId].isDeleted;
    }

    function getStakingDurationInDays(uint256 _startTimestamp, uint256 _endTimestamp) public pure returns (uint256) {
        uint256 durationInSeconds = _endTimestamp - _startTimestamp;
        uint256 durationInDays = durationInSeconds / 60 / 60 / 24;
        return durationInDays;
    }
    
    function calculateStakeRewardWithDefinedAmount(string memory _stakePoolId, uint256 stakeAmount) public view returns(uint256) {

        
        uint256 totalReward = calculateReward( _stakePoolId, stakeAmount);
        return totalReward;
    }


    //total number of the users that has staked
    function getCountOfUsers() public onlyOwner view returns(uint256) {
        return _totalUsers;
    }


    function checkIsPoolExists(string memory _stakePoolId) public view returns(bool) {
        return bytes(_stakePool[_stakePoolId].stakePoolId).length != 0;
    }

    function generateId() private returns (uint256) {
           idCounter++;
            return idCounter;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner();
    }

    function getTokenAddress() public view onlyOwner returns  (address) {
        return address(_token);
    }

    function listAllStakesInPool(string memory stakePoolId) public onlyOwner view returns (Stakes[] memory) {
        return _stakesInPool[stakePoolId];
    }

    function lengthStakesInPool(string memory stakePoolId) public onlyOwner view returns (uint) {
        return _stakesInPool[stakePoolId].length;
    }
       
    function updateStakePool(
        string memory stakePoolId,
        string memory newName,
        uint newStartDate,
        uint newEndDate,
        uint minAPY,
        uint maxAPY,
        uint256 newMinStakingAmount,
        uint256 newMaxStakingLimit
    ) public onlyOwner {
        require(bytes(_stakePool[stakePoolId].stakePoolId).length != 0, "Stake pool not found");



        require(maxAPY <= 10000, "Max APY rate should be less then 10000");
        require(minAPY > 0 && minAPY < maxAPY, "Min APY rate should be less then Max APY and greater than 0");
        require(newStartDate < newEndDate, "Start date cannot be greater than the end date");

        // Update the pool
        _stakePool[stakePoolId].name = newName;
        _stakePool[stakePoolId].startDate = newStartDate;
        _stakePool[stakePoolId].endDate = newEndDate;
        _stakePool[stakePoolId].minAPY = minAPY;

        _stakePool[stakePoolId].maxAPY = minAPY;
        _stakePool[stakePoolId].minStakingAmount = newMinStakingAmount;
        _stakePool[stakePoolId].maxStakingLimit = newMaxStakingLimit;

        emit StakePoolUpdated(
            stakePoolId,
            newName,
            newStartDate,
            newEndDate,
            newMinStakingAmount,
            newMaxStakingLimit
        );
    }

    function getVersion() public pure returns(string memory){
        return VERSION;
    }

    function withdraw(address account, uint256 _amount) public onlyOwner nonReentrant {

        _token.approve(address(this), _amount);
        _token.transferFrom(address(this), account, _amount);
    }
    
}