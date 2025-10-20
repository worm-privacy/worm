// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WORM} from "../src/WORM.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WORMTest is Test {
    function setUp() public {}

    function test_reward() public {
        WORM worm = new WORM(IERC20(address(0)));
        uint256 ts = block.timestamp;
        assertEq(worm.currentEpoch(), 0);
        assertEq(worm.currentReward(), 50 ether);
        vm.warp(ts + 1799);
        assertEq(worm.currentEpoch(), 0);
        assertEq(worm.currentReward(), 50 ether);
        vm.warp(ts + 1800);
        assertEq(worm.currentEpoch(), 1);
        assertEq(worm.currentReward(), 49.999834965229375000 ether);
        vm.warp(ts + 1800 + 1);
        assertEq(worm.currentEpoch(), 1);
        assertEq(worm.currentReward(), 49.999834965229375000 ether);
        vm.warp(ts + 1800 + 1799);
        assertEq(worm.currentEpoch(), 1);
        assertEq(worm.currentReward(), 49.999834965229375000 ether);
        vm.warp(ts + 1800 + 1800);
        assertEq(worm.currentEpoch(), 2);
        assertEq(worm.currentReward(), 49.999669931003479510 ether);
        vm.warp(ts + 1800 * 210000);
        assertEq(worm.currentEpoch(), 210000);
        assertEq(worm.currentReward(), 25.000000000011336525 ether);
        vm.warp(ts + 1800 * 210001);
        assertEq(worm.currentEpoch(), 210001);
        assertEq(worm.currentReward(), 24.999917482626023987 ether);
    }
}
