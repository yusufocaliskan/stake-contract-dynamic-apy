//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

//swap
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract VestingSchedule is ReentrancyGuard, Ownable, AccessControl {

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    event VestingScheduleAdded(address account, uint allocation, uint timestamp, uint vestingSeconds, uint cliffSeconds);

    event VestingScheduleCanceled(address account);

    event AllocationClaimed(address account, uint amount, uint timestamp);
    event EventCreated(string indexed eventName);
    event EventUpdated(string indexed eventName);
    
    struct EventLookup {
        string eventName;
        string eventId;
        uint tgeRate;
        uint startTimestamp;
        uint vestingSeconds;
        uint cliffSeconds;
        string privateAccount;

    }

    mapping(string => EventLookup) private _events;
    
    string[] private _allEventIds;


    struct VestingScheduleStruct {
        address account;
        uint allocation;
        uint startTimestamp;
        uint vestingSeconds;
        uint cliffSeconds;
        uint claimedAmount;
        bool isClaimInTGE;
    }

    mapping( string => mapping ( address => VestingScheduleStruct) ) private _vestingSchedules;

    IERC20 private _token;
    address _tokenAddress;

    uint private _totalAllocation;
    uint private _totalClaimedAllocation;

    //swap
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        
    uint _gptvRate;



    constructor ( address ownerAddress, address tokenAddress_, uint gptvRate ) Ownable(ownerAddress) {

        _tokenAddress = tokenAddress_;
        _token = IERC20(tokenAddress_);

        _gptvRate = gptvRate;

        //Owener permissons
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        //grant it to owner_role
        _grantRole(OWNER_ROLE, ownerAddress);

    }

    function isOwner(address account) public view returns (bool) {
        return account == owner();
    }

    function setTokenAddress(address tokenAddress_) public  onlyOwner {
        _tokenAddress = tokenAddress_;
    }
    // FUNCTIONS

    //Creates new event 
     function createNewEvent(string memory eventName, string memory eventId, 
     uint tgeRate, uint vestingSeconds, uint cliffSeconds,  string memory privateAccount) public onlyOwner {
        if(_events[eventId].tgeRate > 0){
            revert("The event already exists.");
        }

        uint startTimestamp =  block.timestamp;
        _events[eventId] = EventLookup(eventName, 
                            eventId, 
                            tgeRate, 
                            startTimestamp,
                            vestingSeconds, 
                            cliffSeconds,
                            privateAccount);
        _allEventIds.push(eventId);
        emit EventCreated(eventName);
    }

    //Gets events detail by event id
    function getEventById(string memory eventId) public view returns (EventLookup memory) {
        return _events[eventId];
    }

    function getAllEvents() public view returns (EventLookup[] memory) {
        EventLookup[] memory allEvents = new EventLookup[](_allEventIds.length);
        
        for (uint i = 0; i < _allEventIds.length; i++) {
            // Access the event details from the mapping using eventId
            EventLookup storage eventLookup = _events[_allEventIds[i]];
            allEvents[i] = eventLookup;
        }
        
        return allEvents;
    }

    
    function addVestingSchedule(address account, uint allocation, string memory eventId, uint vestingSeconds, uint cliffSeconds) internal  {

        //check if the given event id is exists
        require(_events[eventId].tgeRate > 0, "The event is not exists, create new one if you wish.");

        //if use events timing
        if(vestingSeconds == 0){
            vestingSeconds = _events[eventId].vestingSeconds;
        }

        if(cliffSeconds == 0){
            cliffSeconds = _events[eventId].cliffSeconds;
        }
        
        
        require(_vestingSchedules[eventId][account].account==address(0x0), "ERROR: Vesting Schedule already exists" );

        require(_totalAllocation + allocation <= _token.balanceOf(address(this)), "ERROR: Total allocation cannot be greater than reserves");

        require(cliffSeconds <= vestingSeconds, "ERROR: Cliff longer than Vesting Time");

        require(vestingSeconds > 0, "ERROR: Vesting Time cannot be 0 seconds");

        _totalAllocation += allocation;
        _vestingSchedules[eventId][account] = VestingScheduleStruct({
            account: account, 
            allocation : allocation, 
            startTimestamp: block.timestamp, 
            vestingSeconds: vestingSeconds, 
            cliffSeconds: cliffSeconds,
            claimedAmount: 0,
            isClaimInTGE: false
        });

        emit VestingScheduleAdded(account, allocation, block.timestamp, vestingSeconds, cliffSeconds);
    }
 
    // just to use without swapping
    function addPrivateVestingSchedule(address account, uint allocation, string memory eventId, uint vestingSeconds, uint cliffSeconds) public onlyRole(OWNER_ROLE) {

        addVestingSchedule(account, allocation, eventId, vestingSeconds, cliffSeconds);
    }


    function isUserExistsInTheEvent(address account, string memory eventId) public view returns (bool) {
        if (_vestingSchedules[eventId][account].account != address(0)) {
            return true;
        }

        return false;
    }
    

    function claim( string memory eventId, address account) public  nonReentrant {

        if(_vestingSchedules[eventId][account].account == address(0x0)){
            revert("Vesting schedule does not exist for this account.");
        }

        uint256 amount = getClaimableAmount(eventId, account);
       
        if((amount != _vestingSchedules[eventId][account].allocation ) && _vestingSchedules[eventId][account].isClaimInTGE != true)
        {
            //Calculate TgE Amount 
            uint tgeAmount = calculateTGEAmount(account, eventId); 
 
            amount +=tgeAmount;
            _vestingSchedules[eventId][account].isClaimInTGE = true;
        }

        require(amount > 0, "No token to be claim.");
        _token.transfer(account, amount);
        
        _vestingSchedules[eventId][account].claimedAmount += amount;
        _totalClaimedAllocation += amount;

        emit AllocationClaimed(account, amount, block.timestamp);
    }

    function calculateTGEAmount(address account, string memory eventId) public view returns(uint){

        uint tgeRate = _events[eventId].tgeRate; 
        uint tgeAmount = calculateAmountPercentage(_vestingSchedules[eventId][account].allocation, tgeRate);

        return tgeAmount;
    }

    function calculateAmountPercentage(uint _amount, uint _percentage) internal pure returns (uint) {
        return (_amount * _percentage) / 100;

    }

    function setGPTVRate(uint rate) public onlyOwner(){
        _gptvRate = rate;
    }  

       function cancel(address account, string memory eventId) external onlyOwner {

           uint unvestedAllocation = getUnvestedAmount( eventId, account);

           _vestingSchedules[eventId][account].allocation = _vestingSchedules[eventId][account].allocation - unvestedAllocation;
           _vestingSchedules[eventId][account].vestingSeconds = getElapsedVestingTime( eventId, account);

            _totalAllocation -= unvestedAllocation;

            emit VestingScheduleCanceled(account);
        }

    function withdraw(address account, uint256 _amount) public onlyOwner nonReentrant {

        _token.approve(address(this), _amount);
        _token.transferFrom(address(this), account, _amount);
    }
    // GETTERS

    ///// global /////
    function getTokenAddress() external view returns (address) {
        return address(_token);
    }

    function getBalanceOfContract() external view onlyOwner returns  (uint256) {
        return _token.balanceOf(address(this));
    }

    function getTotalAllocation() public view returns (uint) {
        return _totalAllocation;
    }

    function getRemainedResource() public view returns (uint) {
        return _token.balanceOf(address(this))-_totalAllocation;
    }



    function getTotalClaimedAllocation() external view returns (uint) {
        return _totalClaimedAllocation;
    }

    ///// by vesting definition /////
    function getVestingSchedule( string memory eventId, address account) external view returns (VestingScheduleStruct memory) {

        return _vestingSchedules[eventId][account];
    }

    function getVestingMaturationTimestamp( string memory eventId, address account) public view returns (uint) {

        return getStartTimestamp(account, eventId) + getVestingSeconds(account, eventId);
    }

    function getElapsedVestingTime( string memory eventId, address account) public view returns (uint) {

        uint maturationTime = getVestingMaturationTimestamp(eventId, account);
        if(block.timestamp > maturationTime){
            return getVestingSeconds(account, eventId);
        }
        return block.timestamp - getStartTimestamp(account, eventId);
    }


    function getVestedAmount(string memory eventId, address account) public view returns (uint) {
        uint totalAllocation = _vestingSchedules[eventId][account].allocation;
        uint elapsedVestingTime = getElapsedVestingTime(eventId, account);
        uint vestingSeconds = getVestingSeconds(account, eventId);

        uint tgeAmount = calculateTGEAmount(account, eventId);

        uint remainingAllocation = totalAllocation - tgeAmount;

        uint vestedAmount = (remainingAllocation * elapsedVestingTime) / vestingSeconds;

        return vestedAmount + tgeAmount;
    }

    function getUnvestedAmount(string memory eventId, address account) public view returns (uint) {
        uint vestedAmount = getVestedAmount(eventId, account);
        uint allocation = _vestingSchedules[eventId][account].allocation;

        if (allocation >= vestedAmount) {
            return allocation - vestedAmount;
        } 
        // This means all tokens have been vested
        return 0;
    }

    function getClaimableAmount(string memory eventId, address account) public view returns (uint256) {

        uint256 scheduleTime = (getStartTimestamp(account, eventId) + getCliffSeconds(account, eventId));
        console.log("scheduleTime->",scheduleTime);
        console.log("block.timestamp->",block.timestamp);
        if (block.timestamp < scheduleTime) {
            console.log("Here");
            return 0;
        }

        uint vestedAmount = getVestedAmount(eventId, account);
        uint claimedAmount = _vestingSchedules[eventId][account].claimedAmount;


        uint256 result = vestedAmount - claimedAmount;
        return result;

    }


    function getStartTimestamp(address account, string memory eventId) private view returns(uint){

        uint accounStartTimestamp = _vestingSchedules[eventId][account].startTimestamp;

        //Use events time stamp, if account has not one
        if(accounStartTimestamp == 0){
            return _events[eventId].startTimestamp;
        }

        return accounStartTimestamp;
    }

    function getVestingSeconds(address account, string memory eventId) private view returns(uint){
        uint accountVestingSecs = _vestingSchedules[eventId][account].vestingSeconds;

        if(accountVestingSecs == 0){
            return _events[eventId].vestingSeconds;
        }

        return accountVestingSecs;
    }

    function getCliffSeconds(address account, string memory eventId) private view returns(uint){
        uint accountCliffSecs = _vestingSchedules[eventId][account].cliffSeconds;
        
        if(accountCliffSecs == 0){
            return _events[eventId].cliffSeconds;
        }

        return accountCliffSecs;
    }

    // //Swap 
    // function swapExactInputSingle(address tokenIn, address tokenOut, uint amountIn, string memory eventId) external nonReentrant returns(uint amountOut){


    //     // Get the transfer form user
    //     TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

    //     // approve for token 
    //     TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);
        
    //     // Swap params 
    //     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
    //         tokenIn: tokenIn,
    //         tokenOut: tokenOut,
    //         fee: 3000,
    //         recipient: address(this),
    //         // recipient: msg.sender,
    //         deadline: block.timestamp + 1000,
    //         amountIn: amountIn,
    //         amountOutMinimum: 0,
    //         sqrtPriceLimitX96: 0
    //     });

    //     // Swap yap ve GPTV token miktarını al
    //     amountOut = swapRouter.exactInputSingle(params);

    //     addVestingSchedule(msg.sender, amountOut, eventId, 0, 0);

    //     return amountOut;

    // }
    
    function isEventExists( string memory eventId) public view returns(bool) {
        if(_events[eventId].tgeRate > 0){
            return true;
        }
        return false;

    }

     function updateEventById(string memory eventId, string memory eventName,  
     uint tgeRate, uint vestingSeconds, uint cliffSeconds,  string memory privateAccount) public onlyOwner {

        require(
        keccak256(bytes(_events[eventId].eventId)) == keccak256(bytes(eventId)), "Event not found.");


        _events[eventId].eventName = eventName;
        _events[eventId].tgeRate = tgeRate;
        _events[eventId].vestingSeconds = vestingSeconds;
        _events[eventId].cliffSeconds = cliffSeconds;
        _events[eventId].privateAccount = privateAccount;

        emit EventUpdated(eventName);
    }
}