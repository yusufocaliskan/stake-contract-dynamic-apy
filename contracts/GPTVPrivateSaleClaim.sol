// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GPTSaleAllocation is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    //Claim
    uint256 claimStartDate;
    uint256 claimEndDate;
    uint256 claimElapsedDays;

    //Checkrs
    bool isPaused;

    //TGE
    uint256 tgeStartDate;
    uint256 tgeEndDate;

    //Token = GPTV address
    address tokenAddress;
    IERC20 private token;

    // The percentage of the TGE
    uint256 releasedRate; 


    //user
    struct User{
        uint256 totalAllocation;
        uint256 claimedTokens; //Tokens taken by user since today
        bool isTGETokensClaimed; //did the user claimed the tokens in TGE?
        uint256 lastClaimTime;
        uint256 remainedAllocation;
        uint256 amountClaimedInTheTGE; // The amount that the user took in the TGE
        bool isClaimedToday;
    }

    mapping(address => User) public users;
    mapping(address => address) public userClaimed;


    //Is the event paused?
    modifier checkIfIsPuased(){
        if(isPaused){
            revert("The event is paused.");
        }
        _;
    }

    //Check if event is start or end. etc.
    modifier claimDateController(){

        uint256 currentTime = block.timestamp;

        //did the claim start?
        if(claimStartDate > currentTime)
        {
            revert("The event is not started yet.");
        }

        //did the event end?
        if(claimEndDate < currentTime)
        {
            revert("The event has already ended.");
        }

        _;

    }

    modifier tgeDateController(){

        uint256 currentTime = block.timestamp;

        //did the claim start?
        if(tgeStartDate > currentTime)
        {
            revert("The TGE is not started yet.");
        }

        //did the event end?
        if(tgeEndDate < currentTime)
        {
            revert("The TGE has already ended.");
        }

        _;

    }


    //initial
    constructor (address _owner, address _tokenAddress) Ownable(_owner){
        token = IERC20(_tokenAddress);
        isPaused = false;
    }

    
    // ============== Actual functionalities ============== 

    function getTGETokens() public  checkIfIsPuased tgeDateController claimDateController nonReentrant{

    // function getTGETokens() public  nonReentrant returns(uint256){

        //the cliam event start and not ended
        //TGE started, and not ended

        //did the user claimed the tge tokens?
        require(!users[msg.sender].isTGETokensClaimed, "You have already claimed the TGE tokens.");

        //Check if the claimer has allready added to the users map
        require(users[msg.sender].totalAllocation > 0, "You are not a beneficiary");

        //Ve have a user.
        uint256 currentTime = getCurrentTime();

        //Calculate the amount that would be given to the user in TGE
        uint256 tgeClaimedAmount = (users[msg.sender].totalAllocation / 100) * releasedRate;

        ///Then transfer it 
        require(token.transfer(msg.sender, tgeClaimedAmount), "An error occured");

        //Then set the new valueo of the user
        users[msg.sender].claimedTokens += tgeClaimedAmount;
        users[msg.sender].isTGETokensClaimed = true;
        users[msg.sender].lastClaimTime = currentTime;
        users[msg.sender].amountClaimedInTheTGE = tgeClaimedAmount;
        users[msg.sender].remainedAllocation -= tgeClaimedAmount;
        
        userClaimed[msg.sender] = msg.sender;

    }


    function claimToken() public checkIfIsPuased claimDateController nonReentrant {

        // Check if the claimer has already been added to the users map
        require(users[msg.sender].totalAllocation > 0, "You are not a beneficiary");
    
        // Check if the user has claimed the TGE tokens
        require(users[msg.sender].isTGETokensClaimed, "To have the remained tokens you should get the TGE token first.");

        // Check for sufficient token availability for the user
        require(users[msg.sender].remainedAllocation > 0, "No more insufficient token remained.");

        // Ensure the user has not already claimed tokens today
        require(!isToday(users[msg.sender].lastClaimTime), "You have already taken today's tokens.");

        uint256 currentTime = getCurrentTime();
        uint256 totalClaimEventDays = getTotalClaimEventDays();

        // Adjusted daily rate calculation to minimize rounding errors
        // First, multiply the remaining allocation by the daily rate, then divide by 100
        uint256 dailyRate = users[msg.sender].remainedAllocation / totalClaimEventDays; 

        require(dailyRate > 0, "Daily claim amount must be greater than 0");

        // Transfer the calculated amount to the user
        require(token.transfer(msg.sender, dailyRate), "An error occurred");

        // Update user's claim records
        users[msg.sender].claimedTokens += dailyRate;
        users[msg.sender].lastClaimTime = currentTime;
        users[msg.sender].remainedAllocation -= dailyRate;
    }



    // ============== Setters ============== 

    //Adds a new beneficiary
    function addUser(address userAddress, uint256 _totalAllocation) external onlyOwner {

        users[userAddress] = User({
            totalAllocation:_totalAllocation,
            claimedTokens :0,
            isTGETokensClaimed:false,
            amountClaimedInTheTGE:0,
            lastClaimTime: 0,
            remainedAllocation:_totalAllocation,
            isClaimedToday:false
        });
    }

    //Set start date
    //NOTE: Time must be in timestamp format
    function setClaimStartDate(uint256 date) external onlyOwner{

        claimStartDate = date;
    }

    //Set end date
    //NOTE: Time must be in timestamp format
    function setClaimEndDate(uint256 date) external onlyOwner{

        claimEndDate = date;
    }

    //NOTE: Time must be in timestamp format
    function setTGEStartDate(uint256 date) external onlyOwner{

        tgeStartDate = date;
    }


    //NOTE: Time must be in timestamp format
    function setTGEEndDate(uint256 date) external onlyOwner{

        tgeEndDate = date;
    }

    function setReleasedRate(uint256 percentage) external onlyOwner{

        releasedRate = percentage;
    }

    //Toggling between true/false
    function toggleEventStatus() external onlyOwner{
        isPaused = !isPaused;
    }

    // ============== Getters ============== 

    function getUserByAddress(address userAddress) external view onlyOwner returns(uint256, uint256, bool, uint256, uint256, uint256) {
        require(users[userAddress].totalAllocation > 0, "There is no user defined to the contract");

        //Get the user
        User memory user = users[userAddress];


        //Return it 
        return (user.totalAllocation,
            user.claimedTokens,
            user.isTGETokensClaimed,
            user.amountClaimedInTheTGE,
            user.lastClaimTime,
            user.remainedAllocation);
    }

    function getUserDetails() external view returns(uint256, uint256, bool, uint256, uint256, uint256) {
        require(users[msg.sender].totalAllocation > 0, "There is no user defined to the contract");

        //Get the user
        User memory user = users[msg.sender];

        //Return it 
        return (user.totalAllocation,
            user.claimedTokens,
            user.isTGETokensClaimed,
            user.amountClaimedInTheTGE,
            user.lastClaimTime,
            user.remainedAllocation);
    }



    function getUserTGEAvailableAmount() public view returns(uint256){

        //Calculate the amount that would be given to the user in TGE
        uint256 tgeClaimedAmount = (users[msg.sender].totalAllocation / 100) * releasedRate;

        return tgeClaimedAmount;
    }

    function getUseDailyAmount() public view returns(uint256){
        uint256 dailyAmount = users[msg.sender].remainedAllocation / totalClaimEventDays; 
        return dailyAmount
    }

    function getCurrentTime() public view returns(uint256){

        uint256 currentTime = block.timestamp;
        return currentTime;
    }

    function getEventStatus() external view onlyOwner returns(bool){
        return isPaused;
    }
    function getClaimStartDate() public view returns(uint256){
        return claimStartDate;
    }
    function getClaimEndDate() public view returns(uint256){
        return claimEndDate;
    }
    function getTGEStartDate() public view returns(uint256){
        return tgeStartDate;
    }
    function getTGEEndDate() public view returns(uint256){
        return tgeEndDate;
    }

    function isToday(uint256 userClaimTime) internal view returns (bool) {
        uint256 currentTime = block.timestamp; 
        uint256 currentDay = currentTime / 86400;  
        uint256 lastUserDay = userClaimTime / 86400; 
        return currentDay == lastUserDay; 
    }

    function getTotalClaimEventDays() public view returns (uint256) {
         
         uint256 totalDaysOftheClaimEvent = (claimEndDate - claimStartDate) / 86400;
        return  totalDaysOftheClaimEvent;
    }


    
    

}   
