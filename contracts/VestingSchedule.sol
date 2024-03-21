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


    struct VestingScheduleStruct {
        address account;
        uint allocation;
        uint startTimestamp;
        uint vestingSeconds;
        uint cliffSeconds;
        uint claimedAmount;
    }

    mapping( uint => mapping (address => VestingScheduleStruct) ) private _vestingSchedules;




    IERC20 private _token;

    uint private _totalAllocation;
    uint private _totalClaimedAllocation;

    constructor ( address ownerAddress, address tokenAddress ) Ownable(ownerAddress) {
        _token = IERC20(tokenAddress);
    }

    // FUNCTIONS

    function addVestingSchedule(address account, uint allocation, uint vestingSeconds, uint cliffSeconds, uint id) external onlyOwner {

        require(_vestingSchedules[id][account].account==address(0x0), "ERROR: Vesting Schedule already exists" );

        require(cliffSeconds <= vestingSeconds, "ERROR: Cliff longer than Vesting Time");

        require(_totalAllocation + allocation <= _token.balanceOf(address(this)), "ERROR: Total allocation cannot be greater than reserves");

        require(vestingSeconds > 0, "ERROR: Vesting Time cannot be 0 seconds");

        _totalAllocation += allocation;
        _vestingSchedules[id][account] = VestingScheduleStruct({
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

    function claim( uint id) public  nonReentrant {
        address account = msg.sender;
        uint amount = getClaimableAmount(account, id);

        _token.transfer(account, amount);
        
        _vestingSchedules[id][account].claimedAmount += amount;
        _totalClaimedAllocation += amount;

        emit AllocationClaimed(account, amount, block.timestamp);
    }

    function cancel(address account, uint id) external onlyOwner {

        uint unvestedAllocation = getUnvestedAmount(account, id);

        _vestingSchedules[id][account].allocation = _vestingSchedules[id][account].allocation - unvestedAllocation;
        _vestingSchedules[id][account].vestingSeconds = getElapsedVestingTime(account, id);

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
    function getVestingSchedule( uint id) external view returns (VestingScheduleStruct memory) {

        address account = msg.sender;
        return _vestingSchedules[id][account];
    }

    function getVestingMaturationTimestamp( uint id) public view returns (uint) {

        address account = msg.sender;
        return _vestingSchedules[id][account].startTimestamp + _vestingSchedules[id][account].vestingSeconds;
    }

    function getElapsedVestingTime( uint id) public view returns (uint) {

        address account = msg.sender;
        if(block.timestamp > getVestingMaturationTimestamp(account, id)){
            return _vestingSchedules[id][account].vestingSeconds;
        }
        return block.timestamp - _vestingSchedules[id][account].startTimestamp;
    }

    function getVestedAmount( uint id) public view returns (uint) {

        address account = msg.sender;
        return _vestingSchedules[id][account].allocation * getElapsedVestingTime(account, id) / _vestingSchedules[id][account].vestingSeconds;
    }

    function getUnvestedAmount( uint id) public view returns (uint) {

        address account = msg.sender;
        return _vestingSchedules[id][account].allocation - getVestedAmount(account, id);
    }

    function getClaimableAmount( uint id) public view returns (uint) {

        address account = msg.sender;
        //If it's earlier than the cliff, zero allocation is claimable.
        if(block.timestamp < (_vestingSchedules[id][account].startTimestamp + _vestingSchedules[id][account].cliffSeconds ) ){
            return 0;
        }

        //Claimable amount is the vested, unclaimed amount.
        return getVestedAmount(account, id) - _vestingSchedules[id][account].claimedAmount;
    }

}
