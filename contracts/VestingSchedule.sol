//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract VestingSchedule is ReentrancyGuard, Ownable, AccessControl {

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    event VestingScheduleAdded(address account, uint allocation, uint timestamp, uint vestingSeconds, uint cliffSeconds);
    event VestingScheduleCanceled(address account);
    event AllocationClaimed(address account, uint amount, uint timestamp);

    
    struct EventLookup {
        string eventName;
        string eventId;
        uint tgeRate;
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

    constructor ( address ownerAddress, address tokenAddress ) Ownable(ownerAddress) {
        _token = IERC20(tokenAddress);

        //Owener permissons
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);


        //grant it to owen_role
        _grantRole(OWNER_ROLE, ownerAddress);


    }

    // FUNCTIONS

    //Creates new id
     function createNewEvent(string memory eventName, string memory eventId, uint tgeRate) public onlyOwner {
        if(_events[eventId].tgeRate > 0){
            revert("The event already exists.");
        }
        
        _events[eventId] = EventLookup(eventName, eventId, tgeRate);
        _allEventIds.push(eventId);
    }

    //Gets events detail by event id
    function getEventById(string memory key) public view returns (EventLookup memory) {
        return _events[key];
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

    function addVestingSchedule(address account, uint allocation, uint vestingSeconds, uint cliffSeconds, string memory eventId) external onlyRole(OWNER_ROLE) {

        //check if the given event id is exists
        require(_events[eventId].tgeRate > 0, "The event is not exists, create new one if you wish.");

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
            claimedAmount: 0,
            isClaimInTGE: false
        });

        emit VestingScheduleAdded(account, allocation, block.timestamp, vestingSeconds, cliffSeconds);
    }
    

    function claim( string memory eventId, address account) public  nonReentrant {


        uint amount = getClaimableAmount(eventId, account);
        uint tgeRate = _events[eventId].tgeRate; 
        
        if(!_vestingSchedules[eventId][account].isClaimInTGE)
        {
            //Calculate TgE Amount 
            uint tgeAmount = _vestingSchedules[eventId][account].allocation * tgeRate / 100; 
            amount +=tgeAmount;
            _vestingSchedules[eventId][account].isClaimInTGE = true;
        }

        
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
