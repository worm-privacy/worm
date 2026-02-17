// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ICOSwap.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ICOSwapTest is Test {
    ICOSwap swap;
    ERC20Mock tokenToGet;
    ERC20Mock tokenToGive;

    address user = address(1);
    address user2 = address(2);

    function setUp() public {
        tokenToGet = new ERC20Mock();
        tokenToGive = new ERC20Mock();

        swap = new ICOSwap(address(tokenToGet), address(tokenToGive));

        // Mint TokenA to user
        tokenToGet.mint(user, 100 ether);

        // Mint TokenB liquidity to swap contract
        tokenToGive.mint(address(swap), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            SUCCESS CASE
    //////////////////////////////////////////////////////////////*/

    function testExitSuccess() public {
        vm.prank(user);

        swap.exit();

        assertEq(tokenToGive.balanceOf(user), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        REVERT: ZERO BALANCE
    //////////////////////////////////////////////////////////////*/

    function testExitRevertsIfZeroBalance() public {
        vm.prank(user2);

        vm.expectRevert("Balance must be > 0");
        swap.exit();
    }

    /*//////////////////////////////////////////////////////////////
                        REVERT: DOUBLE CLAIM
    //////////////////////////////////////////////////////////////*/

    function testExitRevertsIfAlreadyClaimed() public {
        vm.startPrank(user);

        swap.exit();

        vm.expectRevert("You already got your tokens!");
        swap.exit();

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    REVERT: INSUFFICIENT LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function testExitRevertsIfNotEnoughLiquidity() public {
        // Remove liquidity from swap
        vm.prank(address(swap));
        tokenToGive.transfer(address(0xdead), 100 ether);

        vm.prank(user);

        vm.expectRevert("Not enough Token B liquidity");
        swap.exit();
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE USERS
    //////////////////////////////////////////////////////////////*/

    function testMultipleUsers() public {
        tokenToGet.mint(user2, 50 ether);
        tokenToGive.mint(address(swap), 50 ether);

        vm.prank(user);
        swap.exit();

        vm.prank(user2);
        swap.exit();

        assertEq(tokenToGive.balanceOf(user), 100 ether);
        assertEq(tokenToGive.balanceOf(user2), 50 ether);
    }
}
