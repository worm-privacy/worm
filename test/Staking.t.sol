// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Staking.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract StakingTest is Test {
    ERC20Mock stakingToken;
    ERC20Mock rewardToken;
    Staking staking;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant EPOCH_TIME = 7 days;

    function setUp() public {
        stakingToken = new ERC20Mock();
        rewardToken = new ERC20Mock();
        staking = new Staking(IERC20(address(stakingToken)), IERC20(address(rewardToken)), 7 days);

        // Mint initial balances
        stakingToken.mint(alice, 1000 ether);
        stakingToken.mint(bob, 1000 ether);
        rewardToken.mint(address(this), 1000 ether);

        // Approvals
        vm.startPrank(alice);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        stakingToken.approve(address(staking), type(uint256).max);
        rewardToken.approve(address(staking), type(uint256).max);
        vm.stopPrank();

        // Owner (this contract) approves reward token too
        rewardToken.approve(address(staking), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                               HELPERS
    //////////////////////////////////////////////////////////////*/

    function skipEpochs(uint256 numEpochs) internal {
        vm.warp(block.timestamp + numEpochs * EPOCH_TIME);
    }

    /*//////////////////////////////////////////////////////////////
                               TESTS
    //////////////////////////////////////////////////////////////*/

    function testLockAndRelease() public {
        vm.startPrank(alice);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        vm.startPrank(bob);
        staking.lock(50 ether, 1);
        vm.stopPrank();

        assertEq(stakingToken.balanceOf(address(staking)), 150 ether, "stake not transferred");
        assertEq(stakingToken.balanceOf(alice), 900 ether, "lock failed");
        assertEq(stakingToken.balanceOf(bob), 950 ether, "lock failed");

        // Before release epoch
        skipEpochs(1);
        vm.startPrank(alice);
        vm.expectRevert(); // still locked
        staking.release(0);
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert(); // still locked
        staking.release(0);
        vm.stopPrank();

        // After release epoch
        skipEpochs(1);
        vm.startPrank(bob);
        staking.release(0); // Bob can release
        vm.stopPrank();
        vm.startPrank(alice);
        vm.expectRevert(); // Alice is still locked
        staking.release(0);
        vm.stopPrank();

        // After release epoch
        skipEpochs(1);
        vm.startPrank(alice); // Alice can also release
        staking.release(0);
        vm.stopPrank();

        assertEq(stakingToken.balanceOf(alice), 1000 ether, "release failed");
        assertEq(stakingToken.balanceOf(bob), 1000 ether, "release failed");

        vm.startPrank(alice);
        vm.expectRevert("Already released!");
        staking.release(0);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Already released!");
        staking.release(0);
        vm.stopPrank();
    }

    function testDepositRewardAndClaimSingleStaker() public {
        // Alice locks
        vm.startPrank(alice);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        skipEpochs(1);

        staking.depositReward(50 ether);

        uint256 before = rewardToken.balanceOf(alice);

        skipEpochs(1);

        vm.startPrank(alice);
        staking.claimReward(1, 1);
        vm.stopPrank();

        uint256 after_ = rewardToken.balanceOf(alice);
        assertEq(after_, before + 50 ether, "no reward claimed");
    }

    function testDepositRewardAndClaimTwoStakers() public {
        // Both lock same amount
        vm.startPrank(alice);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        vm.startPrank(bob);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        // Advance epochs
        skipEpochs(1);

        // Deposit 100 RWD for epoch 1
        staking.depositReward(100 ether);

        // Advance epochs
        skipEpochs(1);

        // Each should claim 50 RWD
        vm.startPrank(alice);
        staking.claimReward(1, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        staking.claimReward(1, 1);
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(alice), 50 ether, "wrong reward alice");
        assertEq(rewardToken.balanceOf(bob), 50 ether, "wrong reward bob");
    }

    function testCannotClaimOngoingEpoch() public {
        vm.startPrank(alice);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        staking.depositReward(10 ether);

        // Try to claim before epoch ended
        vm.startPrank(alice);
        assertEq(staking.currentEpoch(), 0);
        vm.expectRevert("Cannot claim ongoing epoch!");
        staking.claimReward(1, 1);
        vm.stopPrank();
    }

    function testGetStakes() public {
        vm.startPrank(alice);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        vm.startPrank(bob);
        staking.lock(100 ether, 2);
        staking.lock(100 ether, 2);
        vm.stopPrank();

        vm.expectRevert("Invalid range!");
        staking.getStakes(alice, 0, 2);

        vm.expectRevert("Invalid range!");
        staking.getStakes(bob, 0, 3);

        vm.expectRevert("Invalid range!");
        staking.getStakes(bob, 1, 2);

        Staking.Stake[] memory stakesAlice = staking.getStakes(alice, 0, 1);
        assertEq(stakesAlice[0].index, 0);
        assertEq(stakesAlice[0].owner, alice);
        assertEq(stakesAlice.length, 1);
        assertEq(staking.getStakesLength(alice), 1);

        Staking.Stake[] memory stakesBob = staking.getStakes(bob, 0, 2);
        assertEq(stakesBob[0].index, 0);
        assertEq(stakesBob[1].index, 1);
        assertEq(stakesBob[0].owner, bob);
        assertEq(stakesBob[1].owner, bob);
        assertEq(stakesBob.length, 2);
        assertEq(staking.getStakesLength(bob), 2);

        Staking.Stake[] memory stakesBob2 = staking.getStakes(bob, 0, 1);
        assertEq(stakesBob2[0].index, 0);
        assertEq(stakesBob2[0].owner, bob);
        assertEq(stakesBob2.length, 1);

        Staking.Stake[] memory stakesBob3 = staking.getStakes(bob, 1, 1);
        assertEq(stakesBob3[0].index, 1);
        assertEq(stakesBob3[0].owner, bob);
        assertEq(stakesBob3.length, 1);
    }
}
