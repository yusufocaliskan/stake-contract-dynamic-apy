//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/utils/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/security/ReentrancyGuard.sol";
import "@pancakeswap/v2-periphery/contracts/interfaces/IPancakeRouter02.sol";
contract VestingSchedule is ReentrancyGuard, Ownable, AccessControl {
    using SafeBEP20 for IBEP20;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    event VestingScheduleAdded(address account, uint allocation, uint timestamp, uint vestingSeconds, uint cliffSeconds);

    event VestingScheduleCanceled(address account);

    event AllocationClaimed(address account, uint amount, uint timestamp);
    
    struct EventLookup {
        string eventName;
        string eventId;
        uint tgeRate;

        uint startTimestamp;
        uint vestingSeconds;
        uint cliffSeconds;

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

    uint private _totalAllocation;
    uint private _totalClaimedAllocation;

    //swap
    //ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        
    IPancakeRouter02 public swapRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // address public constant GPTV = 0x1F56eFffEe38EEeAE36cD38225b66c56E4D095a7; 
    // address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; 
    // address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 

    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant GPTV = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint _gptvRate;



    constructor ( address ownerAddress, address tokenAddress, uint gptvRate ) Ownable(ownerAddress) {
        _token = IERC20(tokenAddress);

        _gptvRate = gptvRate;

        //Owener permissons
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        //grant it to owner_role
        _grantRole(OWNER_ROLE, ownerAddress);


    }

    // FUNCTIONS

    //Creates new event 
     function createNewEvent(string memory eventName, string memory eventId, 
     uint tgeRate, uint vestingSeconds, uint cliffSeconds) public onlyOwner {
        if(_events[eventId].tgeRate > 0){
            revert("The event already exists.");
        }

        uint startTimestamp =  block.timestamp;
        _events[eventId] = EventLookup(eventName, 
                            eventId, 
                            tgeRate, 
                            startTimestamp,
                            vestingSeconds, 
                            cliffSeconds);
        _allEventIds.push(eventId);
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
    

    function claim( string memory eventId, address account) public  nonReentrant {

        
        if(_vestingSchedules[eventId][account].account == address(0x0)){
            revert("Vesting schedule does not exist for this account.");
        }

        uint amount = getClaimableAmount(eventId, account);
        uint tgeRate = _events[eventId].tgeRate; 

         console.log(
            "Getting Claimable Amoount --> Event: %s, Amount :%s, ",
            eventId,
            amount);

       
        if((amount != _vestingSchedules[eventId][account].allocation ) && _vestingSchedules[eventId][account].isClaimInTGE != true)
        {
            //Calculate TgE Amount 
            uint tgeAmount = safeMulDiv(_vestingSchedules[eventId][account].allocation, tgeRate, 100);
 
            amount +=tgeAmount;
            _vestingSchedules[eventId][account].isClaimInTGE = true;

        console.log(
            "Calculatig TGE --> Event: %s, Amount :%s, ",
            eventId,
            amount);
        }

        

        
        require(amount > 0, "No token to be claim.");
         console.log("Start to transfer ");       
        _token.transfer(account, amount);
        
        _vestingSchedules[eventId][account].claimedAmount += amount;
        _totalClaimedAllocation += amount;

        console.log(
            "Transfer is Done. Result --> Event: %s, Amount :%s, Address :%s",
            eventId,
            amount,
            account);



        emit AllocationClaimed(account, amount, block.timestamp);
    }

    function safeMulDiv(uint256 a, uint256 b, uint256 div) private pure returns (uint256) {
        return (a / div) * b + (a % div) * b / div;
    }


    function setGPTVRate(uint rate) public onlyOwner(){
        _gptvRate = rate;
    }  



   // function cancel(address account, string memory eventId) external onlyOwner {

     //   uint unvestedAllocation = getUnvestedAmount( eventId, account);

       // _vestingSchedules[eventId][account].allocation = _vestingSchedules[eventId][account].allocation - unvestedAllocation;
       // _vestingSchedules[eventId][account].vestingSeconds = getElapsedVestingTime( eventId, account);

        //_totalAllocation -= unvestedAllocation;

        //emit VestingScheduleCanceled(account);
    // }

    // GETTERS

    ///// global /////
    function getTokenAddress() external view returns (address) {
        return address(_token);
    }

    function getBalanceOfContract() external view onlyOwner returns  (uint256) {
        return _token.balanceOf(address(this));
    }

    function getTotalAllocation() external view returns (uint) {
        return _totalAllocation;
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

        if(block.timestamp > getVestingMaturationTimestamp(eventId, account)){
            return getVestingSeconds(account, eventId);
        }
        return block.timestamp - getStartTimestamp(account, eventId);
    }

    function getVestedAmount(string memory eventId, address account) public view returns (uint) {
        uint vestingSeconds = getVestingSeconds(account, eventId);
        if (vestingSeconds == 0) {
            return 0;
        }

        uint startTimestamp = getStartTimestamp(account, eventId);
        uint elapsedVestingTime = block.timestamp > startTimestamp + vestingSeconds
                                ? vestingSeconds
                                : block.timestamp - startTimestamp;
        uint totalAllocation = _vestingSchedules[eventId][account].allocation;

        return (totalAllocation * elapsedVestingTime / vestingSeconds);
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

    function getClaimableAmount(string memory eventId, address account) public view returns (uint) {
        if (block.timestamp < (getStartTimestamp(account, eventId) + getCliffSeconds(account, eventId))) {

        console.log(
            "getClaimableAmount #1",
            block.timestamp < (getStartTimestamp(account, eventId) + getCliffSeconds(account, eventId)));


            return 0;
        }

        uint vestedAmount = getVestedAmount(eventId, account);
        uint claimedAmount = _vestingSchedules[eventId][account].claimedAmount;

        if (vestedAmount >= claimedAmount) {

            console.log(
            "getClaimableAmount #2 -- vestedAmount - claimedAmount",
            vestedAmount - claimedAmount);


            return vestedAmount - claimedAmount;
        } 
            console.log(
            "getClaimableAmount #3 -- vestedAmount - claimedAmount",
            0);


        // This should not normally happen, as claimed amount should never exceed vested amount
        return 0;
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

    //Swap 
    function swapExactInputSingle(address tokenIn, address tokenOut, uint amountIn, string memory eventId) external nonReentrant returns(uint amountOut){


        // Get the transfer form user
        IBEP20(tokenIn).safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        // approve for token 
        IBEP20(tokenIn).safeApprove(tokenIn, address(swapRouter), amountIn);
        
        // Swap params 
        IPancakeRouter02.ExactInputSingleParams memory params = IPancakeRouter02.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000,
            recipient: address(this),
            // recipient: msg.sender,
            deadline: block.timestamp + 1000,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Swap yap ve GPTV token miktarını al
        amountOut = swapRouter.exactInputSingle(params);
        console.log(
            "Swapiing --> Event: %s, AmountIn :%s, AmountOut :%s",
            eventId,
            amountIn,
            amountOut);


        addVestingSchedule(msg.sender, amountOut, eventId, 0, 0);

        return amountOut;

    }
}
