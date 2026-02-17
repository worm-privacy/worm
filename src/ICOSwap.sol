// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ICOSwap {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenToGet;
    IERC20 public immutable tokenToGive;

    mapping(address => bool) public nullified;

    constructor(address _tokenToGet, address _tokenToGive) {
        tokenToGet = IERC20(_tokenToGet);
        tokenToGive = IERC20(_tokenToGive);
    }

    function exit() external {
        uint256 balance = tokenToGet.balanceOf(msg.sender);
        require(balance > 0, "Balance must be > 0");
        require(!nullified[msg.sender], "You already got your tokens!");
        nullified[msg.sender] = true;

        // Contract must have enough Token B
        require(tokenToGive.balanceOf(address(this)) >= balance, "Not enough Token B liquidity");

        // Send Token B to user (1:1 ratio)
        tokenToGive.safeTransfer(msg.sender, balance);
    }
}
