// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GPTVPrivateSaleClaim is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public immutable token;
    uint256 public tgeDate;
    uint256 public claimStartDate;
    uint256 public claimEndDate;
    uint256 public totalAllocation;

    mapping(address => uint256) public allocations;
    mapping(address => uint256) public claimed;
    mapping(address => uint256) public lastClaimDate;

    uint256 public allocatedAmount;


    event TokensClaimed(address claimant, uint256 amount);

    constructor(address _initialOwner, address _tokenAddress, uint256 _totalAllocation) Ownable(_initialOwner){
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(_tokenAddress);
        totalAllocation = _totalAllocation;
      
    }

    function setAllocation(address _beneficiary, uint256 _amount) external onlyOwner {

        require(_amount + allocatedAmount <= totalAllocation, "Allocation exceeds total allocation");
        allocations[_beneficiary] += _amount;
        allocatedAmount += _amount;
    }


    function claimTokens() external nonReentrant {
        require(block.timestamp >= claimStartDate, "Claim period has not started");
        require(block.timestamp <= claimEndDate, "Claim period is over");

        //uint256 totalEventDays = getTotalEventDays();

        //uint256 daysPassed = (block.timestamp - claimStartDate) / 1 days;
        //uint256 totalClaimable = totalAllocation.mul(daysPassed).div(totalEventDays);
        uint256 availableToClaim = getDailyAvailableAllocation();

        require(availableToClaim > 0, "No tokens available to claim");
        require(allocations[msg.sender] >= availableToClaim, "Claim amount exceeds allocation");

        uint256 currentDay = block.timestamp / 1 days;
        require(lastClaimDate[msg.sender] != currentDay, "Already claimed today");

        claimed[msg.sender] = claimed[msg.sender].add(availableToClaim);
        lastClaimDate[msg.sender] = currentDay;

        require(token.transfer(msg.sender, availableToClaim), "Token transfer failed");

        emit TokensClaimed(msg.sender, availableToClaim);
    }
    
    function getDailyAvailableAllocation() public view returns (uint256){
        uint256 daysPassed = (block.timestamp - claimStartDate) / 1 days;
        uint256 totalEventDays = getTotalEventDays();
        uint256 totalClaimable = totalAllocation.mul(daysPassed).div(totalEventDays);
        uint256 availableToClaim = totalClaimable.sub(claimed[msg.sender]);
        return availableToClaim;
    }

    function getPassedDays() public view returns (uint256){
        uint256 daysPassed = (block.timestamp - claimStartDate) / 1 days;
        return daysPassed;
    }
    
    function getTotalClaimable() public view returns (uint256){
        uint256 daysPassed = (block.timestamp - claimStartDate) / 1 days;
        uint256 totalEventDays = getTotalEventDays();
        uint256 totalClaimable = totalAllocation.mul(daysPassed).div(totalEventDays);
        return totalClaimable;
    }

    function getTotalEventDays() public view returns(uint256){
        uint256 timeDiff = claimEndDate - claimStartDate;
        uint256 daysBetween = timeDiff / 86400; // 24 * 60 * 60
        return daysBetween;
    }

    function remainingClaimable(address _beneficiary) public view returns (uint256) {
        getTotalClaimable();
        return allocations[_beneficiary] > claimed[_beneficiary] ? allocations[_beneficiary] - claimed[_beneficiary] : 0;
    }
    

    function setStartDate(uint256 date) public onlyOwner{
        claimStartDate = date;
    }

    function setEndDate(uint256 date) public onlyOwner{
        claimEndDate = date;
    }
    
    function setTGEDate(uint256 date) public onlyOwner{
        tgeDate = date;
    }

    function setTotalAllocation(uint256 amount) public onlyOwner{
        totalAllocation = amount;
    }

    function getBalanceOf() public view onlyOwner returns(uint256){
        return token.balanceOf(address(this));
    }
    

}
