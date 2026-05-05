// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWNativeToken} from "src/hooks/cypher-eth/IWNativeToken.sol";
import {ISwapRouter} from "src/hooks/cypher-eth/ISwapRouter.sol";
import {IV3SwapRouter} from "src/hooks/uniswap/IV3SwapRouter.sol";

/// this contract swaps your BETH to WETH using cypherETH and then swaps your WETH to any ERC-20 with path you provide
/// for path use V3 path and not V2
contract BETHToERC20 {
    IERC20 public immutable bethContract;
    IWNativeToken public immutable wethContract;
    ISwapRouter public immutable cypherETHRouter;
    IV3SwapRouter public immutable uniswapRouter;

    constructor(
        IERC20 _bethContract,
        IWNativeToken _wethContract,
        ISwapRouter _cypherETHRouter,
        IV3SwapRouter _uniswapRouter
    ) {
        require(address(_bethContract) != address(0), "Invalid BETH address");
        require(address(_wethContract) != address(0), "Invalid WETH address");
        require(address(_cypherETHRouter) != address(0), "Invalid WETH address");
        require(address(_uniswapRouter) != address(0), "Invalid WETH address");
        bethContract = _bethContract;
        wethContract = _wethContract;
        cypherETHRouter = _cypherETHRouter;
        uniswapRouter = _uniswapRouter;
    }

    function swapBethWithERC20(uint256 _bethAmountIn, bytes memory _path, address _recipient) public {
        require(_bethAmountIn > 0, "Amount must be greater than 0");
        require(_recipient != address(0), "Invalid recipient");

        require(
            bethContract.transferFrom(msg.sender, address(this), _bethAmountIn), "error while transferFrom beth to this"
        );

        // BETH -> WETH
        bethContract.approve(address(cypherETHRouter), _bethAmountIn);
        uint256 wethAmount = cypherETHRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(bethContract),
                tokenOut: address(wethContract),
                deployer: address(0),
                recipient: address(this),
                deadline: block.timestamp + 15 minutes,
                amountIn: _bethAmountIn,
                amountOutMinimum: 0,
                limitSqrtPrice: 0
            })
        );
        bethContract.approve(address(cypherETHRouter), 0);

        // WETH -> ERC-20
        wethContract.approve(address(uniswapRouter), wethAmount);
        uniswapRouter.exactInput(
            IV3SwapRouter.ExactInputParams({
                path: _path, recipient: _recipient, amountIn: wethAmount, amountOutMinimum: 0
            })
        );
        wethContract.approve(address(uniswapRouter), 0);
    }
}
