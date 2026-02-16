// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWNativeToken} from "src/hooks/cypher-eth/IWNativeToken.sol";
import {ISwapRouter} from "src/hooks/cypher-eth/ISwapRouter.sol";

contract BETHToETH {
    IERC20 public immutable bethContract;
    IWNativeToken public immutable wethContract;

    constructor(IERC20 _bethContract, IWNativeToken _wethContract) {
        require(address(_bethContract) != address(0), "Invalid BETH address");
        require(address(_wethContract) != address(0), "Invalid WETH address");
        bethContract = _bethContract;
        wethContract = _wethContract;
    }

    function swapBethWithEth(uint256 _swapAmount, address _recipient, ISwapRouter _swapRouter)
        public
        returns (uint256 amountOut)
    {
        require(_swapAmount > 0, "Amount must be greater than 0");
        require(_recipient != address(0), "Invalid recipient");

        require(
            bethContract.transferFrom(msg.sender, address(this), _swapAmount), "error while transferFrom beth to this"
        );

        bethContract.approve(address(_swapRouter), _swapAmount);

        amountOut = _swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(bethContract),
                tokenOut: address(wethContract),
                deployer: address(0),
                recipient: address(this),
                deadline: block.timestamp + 15 minutes,
                amountIn: _swapAmount,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );

        bethContract.approve(address(_swapRouter), 0); // extra safety
        wethContract.withdraw(amountOut);
        (bool success,) = _recipient.call{value: amountOut}("");
        require(success, "ETH transfer failed");
    }

    fallback() external payable {}
}
