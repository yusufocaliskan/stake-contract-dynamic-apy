//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IVestingSchedule {
    function addVestingSchedule(
        address account,
        uint allocation,
        uint vestingSeconds,
        uint cliffSeconds,
        string calldata eventId
    ) external;
}

contract GPTVSwap is ReentrancyGuard, Ownable  {

    
    //IERC20 private _token;
    IVestingSchedule private _vestingSchedule;

    constructor ( address ownerAddress ) Ownable(ownerAddress) {
        //_token = IERC20(tokenAddress);
        address vestingContractAddress = 0xF1a8e0013bA4c02635295c311592a678162A3482;
        _vestingSchedule = IVestingSchedule(vestingContractAddress);
    }

    function swap(address account, uint allocation, uint vestingSeconds, uint cliffSeconds, string memory eventId) external {

        _vestingSchedule.addVestingSchedule( account,  allocation,  vestingSeconds, cliffSeconds, eventId);

    }


}
