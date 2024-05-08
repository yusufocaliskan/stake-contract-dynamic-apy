//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";


interface IVestingSchedule {
    function addVestingSchedule(
        address account,
        uint allocation,
        uint vestingSeconds,
        uint cliffSeconds,
        string calldata eventId
    ) external;
}


contract GPTVSwap is ReentrancyGuard  {

    //UniSwapRouter interface
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; 
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 


    //IERC20 private _token;
    IVestingSchedule private _vestingSchedule;

    // constructor ( address ownerAddress ) Ownable(ownerAddress) {
    //     //_token = IERC20(tokenAddress);
    //     address vestingContractAddress = 0xF1a8e0013bA4c02635295c311592a678162A3482;
    //     _vestingSchedule = IVestingSchedule(vestingContractAddress);
    // }


    // function swapExactInputSingle(uint amountIn) external nonReentrant returns (uint amountOut) {
    //     TransferHelper.safeTransferFrom(DAI, msg.sender, address(this), amountIn);

    //     // Approves the swapRouter to spend the token
    //     TransferHelper.safeApprove(DAI, address(swapRouter), amountIn);
        
    //     // Sets up the swap parameters
    //     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
    //         tokenIn: DAI,
    //         tokenOut: USDC,
    //         fee: 3000,
    //         recipient: msg.sender,
    //         deadline: block.timestamp,
    //         amountIn: amountIn,
    //         amountOutMinimum: 0,
    //         sqrtPriceLimitX96: 0
    //     });

    //     amountOut = swapRouter.exactInputSingle(params);
    // }

    // //Swap 
    function swapExactInputSingle(address tokenIn, address tokenOut, uint amountIn) external nonReentrant returns(uint amountOut){


        // Get the transfer form user
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        // approve for token 
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);
        
        // Swap params 
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
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

        // addVestingSchedule(msg.sender, amountOut, eventId, 0, 0);

        return amountOut;

    }
    

}
