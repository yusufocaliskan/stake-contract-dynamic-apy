//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GPTVSwap is ReentrancyGuard, Ownable  {

    constructor ( address ownerAddress ) Ownable(ownerAddress) {

    }

}
