// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Unwrap} from "../src/Unwrap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract UnwrapTest is Test {
    Unwrap unwrap;
    MockToken token;
    MockToken wrapperToken;

    uint256 masterKey = 0xABCD;
    address master = vm.addr(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        vm.warp(123456);

        token = new MockToken();
        wrapperToken = new MockToken();
        unwrap = new Unwrap(IERC20(token), IERC20(wrapperToken));

        // Fund contract with tokens
        token.mint(address(unwrap), 1_000_000 ether);
        wrapperToken.mint(user, 100 ether);
    }

    function testRedeemWrapperToken() public {
        uint256 redeemAmount = 30 ether;

        // User approves Genesis contract to spend wrapperToken
        vm.prank(user);
        wrapperToken.approve(address(unwrap), redeemAmount);

        // Redeem
        vm.prank(user);
        unwrap.unwrap(redeemAmount);

        // Check balances
        assertEq(wrapperToken.balanceOf(user), 70 ether); // 100 - 30
        assertEq(token.balanceOf(user), redeemAmount); // received 30 token
        assertEq(wrapperToken.balanceOf(address(unwrap)), redeemAmount); // Genesis holds redeemed wrapperToken
    }
}
