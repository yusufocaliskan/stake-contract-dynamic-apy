// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GptVerseStaking is Initializable, ReentrancyGuard, Ownable{


    //================== Properties ========================
    //the user
    struct User{
        uint256 stakeAmount;
        uint256 rewardAmount;
        uint256 lastStakeTime;
        uint256 lastRewardCalculationTime;
        uint256 rewardClaimedSoFar;
    }

    uint256 _totalUsers;


    //User mapping
    mapping(address=>User) private _users;


    //Max and min amount that user allowed
    uint256 _minStakingAmount;
    uint256 _maxStakingLimit;

    //to end the program
    uint256 _stakeEndDate; 
    uint256 _stakeStartDate;

    //How many days you want to allow the user to stake
    uint256 _stakeDays;

    //Total stakes
    uint256 _totalStakedTokens;
    


    //the fee percentage If user unStake earlier than the day expected
    uint256 _earlyUnStakeFeePercentage;


    //Is there any problem? Pause the staking
    bool _isStakingPaused;


    //Address of the Staking 
    address private _tokenAddress;


    //annual percentage rate
    uint256 _apyRate;


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

    constructor( address initialOwner, address tokenAddress_,
        uint256 apyRate_,uint256 minStakingAmount_, uint256 maxStakingLimit_,
        uint256 stakeStartDate_, uint256 stakeEndDate_,
        uint256 stakeDays_,uint256 earlyUnStakeFeePercentage_) Ownable(initialOwner) 
        {

            require(apyRate_ <= 10000, "TStaking--> APY rate should be less then 10000");

            require(stakeDays_ > 0, "TStaking--> Stake days invalid, must be greater then 0");

            require(tokenAddress_ != address(0), "TStaking--> The token address connot be 0");

            require(stakeStartDate_ < stakeEndDate_, "TStaking--> Start date connot be greater than the end date");

        
            _tokenAddress = tokenAddress_;
            _apyRate = apyRate_;

            //sets limits
            _minStakingAmount = minStakingAmount_;
            _maxStakingLimit = maxStakingLimit_;

            //set dates
            _stakeStartDate = stakeStartDate_;
            _stakeEndDate = stakeEndDate_;
            _stakeDays = stakeDays_ * 1 days;

            //percentages

            _earlyUnStakeFeePercentage = earlyUnStakeFeePercentage_;



    }



    //================== GETTERS ========================

    function getMinStakingAmount() external view returns(uint256){
        return _minStakingAmount;
    }

    function getMaxStakingLimit() external view returns(uint256){
        return _maxStakingLimit;
    }

    function getStakeStartDate() external view returns(uint256){
        return _stakeStartDate;
    }


    function getStakeEndDate() external view returns(uint256){
        return _stakeEndDate;
    }
    
    function getTotalStakeTokens() external view returns(uint256){
        return _totalStakedTokens;
    }

    function getTotalUsers() external view returns(uint256){
        return _totalUsers;
    }

    function getStakeDays() external view returns(uint256){
        return _stakeDays;
    }

    function getEarlyUnStakeFeePercentage() external view returns(uint256){
        return _earlyUnStakeFeePercentage;
    }

    function getGptVerseStakingStatus( )external view returns(bool){
        return _isStakingPaused;
    }

    function getAPY( )external view returns(uint256){
        return _apyRate;
    }


    //Displayes user's estimated rewards
    function getUserEstimatedRewards() external view returns(uint256){

        //calcs this estimated reward
        (uint256 amount,) = _getUserEstimatedRewards(msg.sender) ;

        return _users[msg.sender].rewardAmount + amount;
    }

    function getWithdrawableAmountOfContract() external view returns(uint256){
        return IERC20(_tokenAddress).balanceOf(address(this)) - _totalStakedTokens;
    }


    //Return user's details by given address 
    function getUserDetails(address userAddress) external view returns(User memory){
        return _users[userAddress];
    }


     
    //================== SETTERS ========================
    // ---- those functions  that could be used by the owner ----


    function setMinStakingAmount(uint256 newMinStakingAmount) external onlyOwner {
        _minStakingAmount = newMinStakingAmount;
    }

    function setMaxStakingLimit(uint256 newMaxStakingLimit) external onlyOwner {
        _maxStakingLimit = newMaxStakingLimit;
    }
    
    function setStakingEndDate(uint256 newEndDate) external onlyOwner {
        _stakeEndDate = newEndDate;
    }

    function setEarlyUnStakeFeePercentage(uint256 newPercentage) external onlyOwner {
        _earlyUnStakeFeePercentage = newPercentage;
    }

    // function setEarlyUnStakeFeePercentage(uint256 newPercentage) external onlyOwner {
    //     _earlyUnStakeFeePercentage = newPercentage;
    // }

    function stake4User(uint256 amount, address userAddress) external onlyOwner nonReentrant{
        this.stakeToken( userAddress, amount);
    }


    //Enabling or disabling the staking
    function toggleStakingStatus() external onlyOwner{
        _isStakingPaused = !_isStakingPaused;
    }

    //Returns the currentTime of the contract
    function getCurrentTime() external view returns(uint256){
        return block.timestamp;

    }
 //================== SOME UTILS  ========================
    
    //Is the given user address is a stake holder?
    function isUserAStakeHoler(address userAddress) external view returns(bool){
        return _users[userAddress].stakeAmount != 0;
    }


    function _calculateRewards(address userAddress) private {
        (uint256 userReward, uint256 currentTime) = _getUserEstimatedRewards(userAddress);
        _users[userAddress].rewardAmount += userReward;
        _users[userAddress].lastRewardCalculationTime = currentTime; // Corrected the assignment
    }




    //================== ACTUAL FUNCTIONALTIES of the CONTRACT  ========================


    //Transfering the amoun to the msg.sender
    function widthdraw(uint256 amount ) external onlyOwner nonReentrant{
        require(this.getWithdrawableAmountOfContract() >= amount,"TStaking --> not enough withdrawble tokens");

        IERC20(_tokenAddress).transfer(msg.sender, amount);
    }


    //gets the amount that the users wants 
    function stakeToken(address userAddress, uint256 _amount) external nonReentrant{
        
        //is the staking paused?
        require(!_isStakingPaused,"TStaking--> Staking is paused");

        //Check for the time
        uint256 currentTime = this.getCurrentTime();
        require(currentTime > _stakeStartDate, "TStaking--> Staking not started yet");
        require(currentTime < _stakeEndDate, "TStaking--> Staking ended");

        //Check for the amounts
        require(_totalStakedTokens + _amount <= _maxStakingLimit, "Max staking token limit reached");

        require(_amount > 0, "Stake amount must be non-zero.");

        require( _amount >= _minStakingAmount, "Stake Amount must be greater than min. amount allowed.");

        // is the user's balances includes? (do we have) 
        if(_users[userAddress].stakeAmount != 0){
            //Then calc it
            _calculateRewards(userAddress);
        }else{
            _users[userAddress].lastRewardCalculationTime = currentTime;
            _totalUsers +=1;
        }



        //Update the users info
        _users[userAddress].stakeAmount += _amount;
        _users[userAddress].lastStakeTime += currentTime;

        _totalStakedTokens += _amount;

        //make the transfer
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);

        //Throw an emit
        emit Stake(userAddress, _amount);
    }

    //unstaking token
    function unstakeToken(uint256 _amount) external nonReentrant whenTreasuryHasBalance(_amount){

        address user = msg.sender;
        require(_amount != 0, "Amount should be non-zero");
        bool chekIsUserAHolder = this.isUserAStakeHoler(user);
        require(chekIsUserAHolder, "You are not a stakeholder.");
        require(_users[user].stakeAmount >= _amount, "Not enough stake to unstake.");

        //calc the user's rewards

        _calculateRewards(user);

        uint256 feeEarlyUnStake; 
        uint256 currentTime = this.getCurrentTime();

        if(currentTime <= _users[user].lastStakeTime + _stakeDays){
            feeEarlyUnStake = ((_amount * _earlyUnStakeFeePercentage) / PERCENTAGE_DENOMINATOR);
            emit EarlyUnStakeFee(user, feeEarlyUnStake);
        }

        uint256 amount2UnStake = _amount -feeEarlyUnStake;

        _users[user].stakeAmount -= _amount;
        _totalStakedTokens -= _amount;

        if(_users[user].stakeAmount == 0){
            _totalUsers -= 1;
        }
        
        IERC20(_tokenAddress).transfer(user, amount2UnStake);
        emit UnStake(user, _amount);

    }

    function claimReward() external nonReentrant whenTreasuryHasBalance(_users[msg.sender].rewardAmount) {

        _calculateRewards(msg.sender);

        uint256 rewardAmount = _users[msg.sender].rewardAmount;


        require(rewardAmount >0,"No reward to claim");

        IERC20(_tokenAddress).transfer(msg.sender, rewardAmount);

        _users[msg.sender].rewardAmount = 0;
        _users[msg.sender].rewardClaimedSoFar -= rewardAmount;

        emit ClaimReward(msg.sender, rewardAmount);


    }

   

    function _getUserEstimatedRewards(address userAddress) private view  returns(uint256, uint256){

        uint256 userReward;
        uint256 userTimestamp = _users[userAddress].lastRewardCalculationTime;

        uint256 currentTime = this.getCurrentTime();

        if(currentTime > _users[userAddress].lastStakeTime + _stakeDays){

            currentTime = _users[userAddress].lastStakeTime + _stakeDays;
        }

        uint256 totalStakedTime = currentTime - userTimestamp;

        userReward += ((totalStakedTime * _users[userAddress].stakeAmount * _apyRate) / 365 days) / PERCENTAGE_DENOMINATOR;

    return (userReward, currentTime);

    }

    

    

    
}