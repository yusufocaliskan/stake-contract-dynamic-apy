//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingSchedule is ReentrancyGuard, Ownable  {

    // bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    event VestingScheduleAdded(address account, uint allocation, uint timestamp, uint vestingSeconds, uint cliffSeconds);
    event VestingScheduleCanceled(address account);
    event AllocationClaimed(address account, uint amount, uint timestamp);

    struct EventLookup {
        string eventName;
        string eventId;
    }
    
    mapping(string => EventLookup[])  _events;
    string[] private _allEventIds;


    struct VestingScheduleStruct {
        address account;
        uint allocation;
        uint startTimestamp;
        uint vestingSeconds;
        uint cliffSeconds;
        uint claimedAmount;
    }

    mapping( string => mapping ( address => VestingScheduleStruct) ) private _vestingSchedules;




    IERC20 private _token;

    uint private _totalAllocation;
    uint private _totalClaimedAllocation;

    constructor ( address ownerAddress, address tokenAddress ) Ownable(ownerAddress) {
        _token = IERC20(tokenAddress);
    }

    // FUNCTIONS

    //Creates new id
     function createNewEvent(string memory eventName, string memory eventId) public onlyOwner {
        _events[eventId].push(EventLookup(eventName, eventId));
        _allEventIds.push(eventId);
    }

    //Gets events detail by event id
    function getEventById(string memory key) public view returns (EventLookup[] memory) {
        return _events[key];
    }


    //Retuns create events
    function getAllEventIds() public view returns (string[] memory) {
        return _allEventIds;
    }

    function addVestingSchedule(address account, uint allocation, uint vestingSeconds, uint cliffSeconds, string memory eventId) external onlyOwner {

        //check if the given event id is exists
        require(_events[eventId].length > 0, "The event is not exists, create new one if you wish.");

        require(_vestingSchedules[eventId][account].account==address(0x0), "ERROR: Vesting Schedule already exists" );

        require(cliffSeconds <= vestingSeconds, "ERROR: Cliff longer than Vesting Time");

        require(_totalAllocation + allocation <= _token.balanceOf(address(this)), "ERROR: Total allocation cannot be greater than reserves");

        require(vestingSeconds > 0, "ERROR: Vesting Time cannot be 0 seconds");

        _totalAllocation += allocation;
        _vestingSchedules[eventId][account] = VestingScheduleStruct({
            account: account, 
            allocation : allocation, 
            startTimestamp: block.timestamp, 
            vestingSeconds: vestingSeconds, 
            cliffSeconds: cliffSeconds,
            claimedAmount: 0
        });

        emit VestingScheduleAdded(account, allocation, block.timestamp, vestingSeconds, cliffSeconds);
    }
    
    //function claim() external  {
      //  return _claim(_msgSender());
    //}

    function claim( string memory eventId, address account) public  nonReentrant {
        
        uint amount = getClaimableAmount(eventId, account);
        require(amount > 0, "No token to be claim.");
        
        _token.transfer(account, amount);
        
        _vestingSchedules[eventId][account].claimedAmount += amount;
        _totalClaimedAllocation += amount;

        emit AllocationClaimed(account, amount, block.timestamp);
    }

    function cancel(address account, string memory eventId) external onlyOwner {

        uint unvestedAllocation = getUnvestedAmount( eventId, account);

        _vestingSchedules[eventId][account].allocation = _vestingSchedules[eventId][account].allocation - unvestedAllocation;
        _vestingSchedules[eventId][account].vestingSeconds = getElapsedVestingTime( eventId, account);

        _totalAllocation -= unvestedAllocation;

        emit VestingScheduleCanceled(account);
    }

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

        return _vestingSchedules[eventId][account].startTimestamp + _vestingSchedules[eventId][account].vestingSeconds;
    }

    function getElapsedVestingTime( string memory eventId, address account) public view returns (uint) {

        if(block.timestamp > getVestingMaturationTimestamp(eventId, account)){
            return _vestingSchedules[eventId][account].vestingSeconds;
        }
        return block.timestamp - _vestingSchedules[eventId][account].startTimestamp;
    }

    function getVestedAmount( string memory eventId, address account) public view returns (uint) {

        
        return _vestingSchedules[eventId][account].allocation * getElapsedVestingTime(eventId, account) / _vestingSchedules[eventId][account].vestingSeconds;
    }

    function getUnvestedAmount( string memory eventId, address account) public view returns (uint) {

        return _vestingSchedules[eventId][account].allocation - getVestedAmount( eventId, account);
    }

    function getClaimableAmount( string memory eventId, address account) public view returns (uint) {

        
        //If it's earlier than the cliff, zero allocation is claimable.
        if(block.timestamp < (_vestingSchedules[eventId][account].startTimestamp + _vestingSchedules[eventId][account].cliffSeconds ) ){
            return 0;
        }

        //Claimable amount is the vested, unclaimed amount.
        return getVestedAmount(eventId, account) - _vestingSchedules[eventId][account].claimedAmount;
    }

}
