// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WORM} from "../src/WORM.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WORMTest is Test {
    function setUp() public {}

    function test_reward() public {
        WORM worm = new WORM(IERC20(address(0)), address(this), 0);
        worm.cacheRewards(10093127);
        uint256 ts = block.timestamp;
        assertEq(worm.currentEpoch(), 0);
        assertEq(worm.currentReward(), 50 ether);
        vm.warp(ts + 599);
        assertEq(worm.currentEpoch(), 0);
        assertEq(worm.currentReward(), 50 ether);
        vm.warp(ts + 600);
        assertEq(worm.currentEpoch(), 1);
        assertEq(worm.currentReward(), 49.999834965229375 ether);
        vm.warp(ts + 600 + 1);
        assertEq(worm.currentEpoch(), 1);
        assertEq(worm.currentReward(), 49.999834965229375 ether);
        vm.warp(ts + 600 + 599);
        assertEq(worm.currentEpoch(), 1);
        assertEq(worm.currentReward(), 49.999834965229375 ether);
        vm.warp(ts + 600 + 600);
        assertEq(worm.currentEpoch(), 2);
        assertEq(worm.currentReward(), 49.99966993100347951 ether);
        vm.warp(ts + 600 * 210000);
        assertEq(worm.currentEpoch(), 210000);
        assertEq(worm.currentReward(), 25.000000000011336525 ether);
        vm.warp(ts + 600 * 210001);
        assertEq(worm.currentEpoch(), 210001);
        assertEq(worm.currentReward(), 24.999917482626023987 ether);
        vm.warp(ts + 600 * (210000 * 2));
        assertEq(worm.currentEpoch(), 210000 * 2);
        assertEq(worm.currentReward(), 12.500000000011298343 ether);
        vm.warp(ts + 600 * (210000 * 2 + 1));
        assertEq(worm.currentEpoch(), 210000 * 2 + 1);
        assertEq(worm.currentReward(), 12.499958741318642055 ether);
        vm.warp(ts + 600 * (210000 * 3));
        assertEq(worm.currentEpoch(), 210000 * 3);
        assertEq(worm.currentReward(), 6.250000000008426341 ether);
        vm.warp(ts + 600 * (210000 * 3 + 1));
        assertEq(worm.currentEpoch(), 210000 * 3 + 1);
        assertEq(worm.currentReward(), 6.249979370662098188 ether);
        vm.warp(ts + 600 * 10093126);
        assertEq(worm.currentEpoch(), 10093126);
        assertEq(worm.currentReward(), 1);
        vm.warp(ts + 600 * 10093127);
        assertEq(worm.currentEpoch(), 10093127);
        assertEq(worm.currentReward(), 0);
        uint256 sumRewards = 0;
        for (uint256 i = 0; i < 10093127; i++) {
            sumRewards += worm.cachedReward(i);
        }
        assertEq(sumRewards, 15148322929356316021917252);
    }
}
