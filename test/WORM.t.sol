// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WORM} from "../src/WORM.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract WORMTest is Test {
    WORM public worm;
    ERC20Mock public beth;
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public {
        beth = new ERC20Mock();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Distribute BETH to test users
        uint256 initialBalance = 10000 ether;
        beth.mint(alice, initialBalance);
        beth.mint(bob, initialBalance);
        beth.mint(charlie, initialBalance);
    }

    function test_reward() public {
        worm = new WORM(IERC20(address(0)), address(this), 0, 0);
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

    function test_constructor() public {
        uint256 preMineAmount = 1000 ether;
        // Test with preMine
        worm = new WORM(IERC20(address(beth)), alice, preMineAmount, 0);
        assertEq(address(worm.bethContract()), address(beth));
        assertEq(worm.startingTimestamp(), block.timestamp);
        assertEq(worm.cachedReward(0), 50 ether);
        assertEq(worm.balanceOf(alice), preMineAmount);
        assertEq(worm.totalSupply(), preMineAmount);

        // Test without preMine
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);
        assertEq(worm.totalSupply(), 0);
    }

    function test_currentEpoch() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);
        uint256 startTime = block.timestamp;

        assertEq(worm.currentEpoch(), 0);

        vm.warp(startTime + 599);
        assertEq(worm.currentEpoch(), 0);

        vm.warp(startTime + 600);
        assertEq(worm.currentEpoch(), 1);

        vm.warp(startTime + 1200);
        assertEq(worm.currentEpoch(), 2);

        vm.warp(startTime + 600 * 100);
        assertEq(worm.currentEpoch(), 100);
    }

    function test_rewardOf() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        // Epoch 0 should be initial reward
        assertEq(worm.rewardOf(0), 50 ether);

        // Epoch 1 should be decayed
        // REWARD_DECAY_NUMERATOR = 9999966993045875;
        // REWARD_DECAY_DENOMINATOR = 10000000000000000;
        // So reward for epoch 1, reward is:
        // 50 * (9999966993045875 / 10000000000000000) = approx 49.999834965229375 ether
        uint256 epoch1Reward = worm.rewardOf(1);
        assertLt(epoch1Reward, 50 ether);

        // Epoch 2 should be further decayed
        uint256 epoch2Reward = worm.rewardOf(2);
        assertLt(epoch2Reward, epoch1Reward);
    }

    function test_cacheRewards() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        assertEq(worm.cachedRewardEpoch(), 0);

        worm.cacheRewards(10);
        assertEq(worm.cachedRewardEpoch(), 10);

        // Verify cached values match calculated values
        for (uint256 i = 0; i <= 10; i++) {
            assertEq(worm.cachedReward(i), worm.rewardOf(i));
        }

        // Cache more epochs
        worm.cacheRewards(100);
        assertEq(worm.cachedRewardEpoch(), 100);
    }

    function test_participate_with_zero_epochs() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        vm.startPrank(alice);
        beth.approve(address(worm), 100 ether);
        vm.expectRevert("Invalid epoch number.");
        worm.participate(100 ether, 0);
        vm.stopPrank();
    }

    function test_participate_single_epoch_by_single_user() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 amount = 100 ether;
        vm.startPrank(alice);
        beth.approve(address(worm), amount);

        uint256 bethBalanceBefore = beth.balanceOf(alice);
        worm.participate(amount, 1);
        uint256 bethBalanceAfter = beth.balanceOf(alice);

        assertEq(bethBalanceBefore - bethBalanceAfter, amount);
        assertEq(beth.balanceOf(address(worm)), amount);
        assertEq(worm.epochTotal(0), amount);
        assertEq(worm.epochUser(0, alice), amount);
        vm.stopPrank();

        // Move to next epoch
        vm.warp(block.timestamp + 600);
        assertEq(worm.currentEpoch(), 1);

        // Claim
        vm.prank(alice);
        worm.claim(0, 1);

        // Alice should receive the full reward for epoch 0
        assertEq(worm.balanceOf(alice), worm.rewardOf(0));
        // Update cached rewards
        assertEq(worm.cachedRewardEpoch(), 1);
        // User's participation should be zeroed out
        assertEq(worm.epochUser(0, alice), 0);
    }

    function test_participate_multi_epochs_by_single_user() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 amountPerEpoch = 50 ether;
        uint256 numEpochs = 3;

        vm.startPrank(alice);
        beth.approve(address(worm), amountPerEpoch * numEpochs);
        worm.participate(amountPerEpoch, numEpochs);
        vm.stopPrank();

        // Verify participation in all epochs
        for (uint256 i = 0; i < numEpochs; i++) {
            assertEq(worm.epochTotal(i), amountPerEpoch);
            assertEq(worm.epochUser(i, alice), amountPerEpoch);
        }

        // Verify total beth participation
        assertEq(beth.balanceOf(address(worm)), amountPerEpoch * numEpochs);

        // Move past all epochs
        vm.warp(block.timestamp + 600 * numEpochs);
        // Claim
        vm.prank(alice);
        worm.claim(0, numEpochs);

        // Alice should receive the full reward for epoch 0, 1, and 2
        uint256 expectedReward = worm.rewardOf(0) + worm.rewardOf(1) + worm.rewardOf(2);
        assertEq(worm.balanceOf(alice), expectedReward);

        // Update cached rewards
        assertEq(worm.cachedRewardEpoch(), 3);

        // User's participation should be zeroed out
        for (uint256 i = 0; i < numEpochs; i++) {
            assertEq(worm.epochUser(i, alice), 0);
        }
    }

    function test_participate_single_epoch_by_multi_users() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 aliceAmount = 10 ether;
        uint256 bobAmount = 30 ether;
        uint256 charlieAmount = 70 ether;
        uint256 totalAmount = aliceAmount + bobAmount + charlieAmount;

        // Move 10 epochs to start
        vm.warp(block.timestamp + 600 * 10);
        uint256 participationEpoch = worm.currentEpoch();

        vm.startPrank(alice);
        beth.approve(address(worm), aliceAmount);
        worm.participate(aliceAmount, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        beth.approve(address(worm), bobAmount);
        worm.participate(bobAmount, 1);
        vm.stopPrank();

        vm.startPrank(charlie);
        beth.approve(address(worm), charlieAmount);
        worm.participate(charlieAmount, 1);
        vm.stopPrank();

        assertEq(worm.epochTotal(participationEpoch), totalAmount);
        assertEq(worm.epochUser(participationEpoch, alice), aliceAmount);
        assertEq(worm.epochUser(participationEpoch, bob), bobAmount);
        assertEq(worm.epochUser(participationEpoch, charlie), charlieAmount);
        assertEq(beth.balanceOf(address(worm)), totalAmount);

        // Move to next epoch
        vm.warp(block.timestamp + 600);
        // Claim
        vm.prank(alice);
        worm.claim(participationEpoch, 1);

        vm.prank(bob);
        worm.claim(participationEpoch, 1);

        vm.prank(charlie);
        worm.claim(participationEpoch, 1);

        uint256 totalReward = worm.rewardOf(participationEpoch);
        uint256 aliceExpectedReward = (totalReward * aliceAmount) / totalAmount;
        uint256 bobExpectedReward = (totalReward * bobAmount) / totalAmount;
        uint256 charlieExpectedReward = (totalReward * charlieAmount) / totalAmount;
        assertEq(worm.balanceOf(alice), aliceExpectedReward);
        assertEq(worm.balanceOf(bob), bobExpectedReward);
        assertEq(worm.balanceOf(charlie), charlieExpectedReward);
        // Rewards based on participation shares
        assertEq(bobExpectedReward / aliceExpectedReward, bobAmount / aliceAmount);
        assertEq(charlieExpectedReward / aliceExpectedReward, charlieAmount / aliceAmount);
        assertEq(charlieExpectedReward / bobExpectedReward, charlieAmount / bobAmount);
        // Due to rounding down, the actual total rewards may be slightly less than totalReward, here is 1 wei
        assertEq(aliceExpectedReward + bobExpectedReward + charlieExpectedReward, totalReward - 1);

        // User's participation should be zeroed out
        assertEq(worm.epochUser(participationEpoch, alice), 0);
        assertEq(worm.epochUser(participationEpoch, bob), 0);
        assertEq(worm.epochUser(participationEpoch, charlie), 0);
    }

    function test_participate_multi_epochs_by_multi_users() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);
        uint256 startTime = block.timestamp;

        // |       | 0 | 1 | 2 | 3 | 4 |
        // -----------------------------
        // |Alice  |100|100|100|100|100|
        // |Bob    |150|150|150|150| 0 |
        // |Charlie| 0 | 0 |200|200|200|
        // Alice participates in epochs 0-4 with varying amounts
        vm.startPrank(alice);
        beth.approve(address(worm), 500 ether);
        worm.participate(100 ether, 5); // 100 BETH per epoch for 5 epochs
        vm.stopPrank();

        // Bob participates in epochs 0-3 with different amount
        vm.startPrank(bob);
        beth.approve(address(worm), 600 ether);
        worm.participate(150 ether, 4); // 150 BETH per epoch for 4 epochs
        vm.stopPrank();

        // Move to epoch 2
        vm.warp(startTime + 600 * 2);

        // Charlie joins mid-way, participates in epochs 2-4
        vm.startPrank(charlie);
        beth.approve(address(worm), 600 ether);
        uint256 charlieApproximatedReward = worm.approximate(200 ether, 3); // 200 BETH per epoch for 3 epochs
        worm.participate(200 ether, 3); // 200 BETH per epoch for 3 epochs
        vm.stopPrank();

        // Verify epoch 0 participation (only Alice and Bob)
        assertEq(worm.epochTotal(0), 250 ether); // 100 + 150
        assertEq(worm.epochUser(0, alice), 100 ether);
        assertEq(worm.epochUser(0, bob), 150 ether);
        assertEq(worm.epochUser(0, charlie), 0);

        // Verify epoch 1 participation (only Alice and Bob)
        assertEq(worm.epochTotal(1), 250 ether); // 100 + 150
        assertEq(worm.epochUser(1, alice), 100 ether);
        assertEq(worm.epochUser(1, bob), 150 ether);
        assertEq(worm.epochUser(1, charlie), 0);

        // Verify epoch 2 participation (all three users)
        assertEq(worm.epochTotal(2), 450 ether); // 100 + 150 + 200
        assertEq(worm.epochUser(2, alice), 100 ether);
        assertEq(worm.epochUser(2, bob), 150 ether);
        assertEq(worm.epochUser(2, charlie), 200 ether);

        // Verify epoch 3 participation (all three users)
        assertEq(worm.epochTotal(3), 450 ether); // 100 + 150 + 200
        assertEq(worm.epochUser(3, alice), 100 ether);
        assertEq(worm.epochUser(3, bob), 150 ether);
        assertEq(worm.epochUser(3, charlie), 200 ether);

        // Verify epoch 4 participation (Alice and Charlie only)
        assertEq(worm.epochTotal(4), 300 ether); // 100 + 200
        assertEq(worm.epochUser(4, alice), 100 ether);
        assertEq(worm.epochUser(4, bob), 0);
        assertEq(worm.epochUser(4, charlie), 200 ether);

        // Move to epoch 5 (all epochs completed)
        vm.warp(startTime + 600 * 5);

        uint256 aliceCalculatedReward = worm.calculateMintAmount(0, 5, alice);
        uint256 bobCalculatedReward = worm.calculateMintAmount(0, 4, bob);
        uint256 charlieCalculatedReward = worm.calculateMintAmount(2, 3, charlie);

        // Alice claims all 5 epochs
        vm.prank(alice);
        worm.claim(0, 5);

        // Bob claims epochs 0-3
        vm.prank(bob);
        worm.claim(0, 4);

        // Charlie claims epochs 2-4
        vm.prank(charlie);
        worm.claim(2, 3);

        // Verify rewards distribution
        // Epoch 0: Alice gets 100/250 = 40%, Bob gets 150/250 = 60%
        // Epoch 1: Alice gets 100/250 = 40%, Bob gets 150/250 = 60%
        // Epoch 2: Alice gets 100/450 = 22.22%, Bob gets 150/450 = 33.33%, Charlie gets 200/450 = 44.44%
        // Epoch 3: Alice gets 100/450 = 22.22%, Bob gets 150/450 = 33.33%, Charlie gets 200/450 = 44.44%
        // Epoch 4: Alice gets 100/300 = 33.33%, Charlie gets 200/300 = 66.66%

        uint256 aliceReward = worm.balanceOf(alice);
        uint256 bobReward = worm.balanceOf(bob);
        uint256 charlieReward = worm.balanceOf(charlie);

        // Verify total rewards equals total minted
        uint256 totalMinted = aliceReward + bobReward + charlieReward;
        uint256 totalRewards =
            worm.rewardOf(0) + worm.rewardOf(1) + worm.rewardOf(2) + worm.rewardOf(3) + worm.rewardOf(4);
        // Due to rounding down, totalMinted may be slightly less than totalRewards, here is 3 wei
        assertEq(totalMinted, totalRewards - 3);

        // Verify Alice's reward
        uint256 expectedAliceReward = (worm.rewardOf(0) * 100) / 250 // Epoch 0: 40%
            + (worm.rewardOf(1) * 100) / 250 // Epoch 1: 40%
            + (worm.rewardOf(2) * 100) / 450 // Epoch 2: 22.22%
            + (worm.rewardOf(3) * 100) / 450 // Epoch 3: 22.22%
            + (worm.rewardOf(4) * 100) / 300; // Epoch 4: 33.33%
        assertEq(aliceReward, expectedAliceReward);
        assertEq(aliceCalculatedReward, expectedAliceReward);

        // Verify Bob's reward
        uint256 expectedBobReward = (worm.rewardOf(0) * 150) / 250 // Epoch 0: 60%
            + (worm.rewardOf(1) * 150) / 250 // Epoch 1: 60%
            + (worm.rewardOf(2) * 150) / 450 // Epoch 2: 33.33%
            + (worm.rewardOf(3) * 150) / 450; // Epoch 3: 33.33%
        assertEq(bobReward, expectedBobReward);
        assertEq(bobCalculatedReward, expectedBobReward);

        // Verify Charlie's reward
        uint256 expectedCharlieReward = (worm.rewardOf(2) * 200) / 450 // Epoch 2: 44.44%
            + (worm.rewardOf(3) * 200) / 450 // Epoch 3: 44.44%
            + (worm.rewardOf(4) * 200) / 300; // Epoch 4: 66.67%
        assertEq(charlieReward, expectedCharlieReward);
        assertEq(charlieCalculatedReward, expectedCharlieReward);
        assertEq(charlieApproximatedReward, charlieCalculatedReward);

        // Verify all participation has been cleared after claiming
        for (uint256 i = 0; i < 5; i++) {
            assertEq(worm.epochUser(i, alice), 0);
        }
        for (uint256 i = 0; i < 4; i++) {
            assertEq(worm.epochUser(i, bob), 0);
        }
        for (uint256 i = 2; i < 5; i++) {
            assertEq(worm.epochUser(i, charlie), 0);
        }
    }

    function test_claim_ongoing_epoch() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 amount = 100 ether;
        vm.startPrank(alice);
        beth.approve(address(worm), amount);
        worm.participate(amount, 1);

        // Try to claim in the same epoch
        vm.expectRevert("Cannot claim an ongoing epoch!");
        worm.claim(0, 1);
        vm.stopPrank();
    }

    function test_calculateMintAmount() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);
        uint256 startTime = block.timestamp;

        uint256 amount = 100 ether;
        vm.startPrank(alice);
        beth.approve(address(worm), amount);
        worm.participate(amount, 1);
        vm.stopPrank();

        // Move to next epoch
        vm.warp(startTime + 600);

        uint256 mintAmount = worm.calculateMintAmount(0, 1, alice);
        assertEq(mintAmount, 50 ether); // Full reward since alice is the only participant
    }

    function test_approximate() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 amountPerEpoch = 100 ether;
        uint256 numEpochs = 3;

        vm.prank(alice);
        uint256 approximation = worm.approximate(amountPerEpoch, numEpochs);

        // With no other participants, should get full rewards
        uint256 expectedReward = worm.rewardOf(0) + worm.rewardOf(1) + worm.rewardOf(2);
        assertEq(approximation, expectedReward);
    }

    function test_info() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 amount = 100 ether;
        vm.startPrank(alice);
        beth.approve(address(worm), amount * 3);
        worm.participate(amount, 3);
        vm.stopPrank();

        WORM.Info memory info = worm.info(alice, 0, 3);

        assertEq(info.currentEpoch, 0);
        assertEq(info.currentEpochReward, 50 ether);
        assertEq(info.userContribs.length, 3);
        assertEq(info.totalContribs.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(info.userContribs[i], amount);
            assertEq(info.totalContribs[i], amount);
        }
    }

    function test_info_with_default_parameters() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        // Should use default margin (5 epochs before and after)
        WORM.Info memory info = worm.info(alice, 0, 0);

        assertEq(info.since, 0); // Current epoch 0 - 5 = 0 (capped at 0)
        assertEq(info.userContribs.length, 11); // 1 + 2 * 5
        assertEq(info.totalContribs.length, 11); // 1 + 2 * 5
        assertEq(info.currentEpoch, 0);
        assertEq(info.currentEpochReward, 50 ether);
        assertEq(info.totalWorm, 0); // No WORM minted yet
        // Total BETH distributed to alice, bob, charlie, no more participants
        assertEq(info.totalBeth, 30000 ether);
        assertEq(info.epochRemainingTime, 600); // Full epoch time remaining
    }

    function test_epochsWithNonZeroRewards() public {
        worm = new WORM(IERC20(address(beth)), address(0), 0, 0);

        uint256 oneYear = 60 * 60 * 24 * 365;

        uint256 amountPerEpoch = 50 ether;

        vm.startPrank(alice);

        beth.approve(address(worm), 500 ether);
        worm.participate(amountPerEpoch, 3);

        vm.warp(block.timestamp + oneYear); // fast forward one year

        worm.participate(amountPerEpoch, 3);

        vm.warp(block.timestamp + oneYear); // fast forward one year

        vm.stopPrank();

        (uint256 nextEpochToSearch, uint256[] memory result) =
            worm.epochsWithNonZeroRewards(0, worm.currentEpoch(), alice, 100);
        assertEq(result.length, 6);
        assertEq(result[0], 0);
        assertEq(result[1], 1);
        assertEq(result[2], 2);

        assertEq(result[3], 52560);
        assertEq(result[4], 52561);
        assertEq(result[5], 52562);
        assertEq(nextEpochToSearch, worm.currentEpoch());

        (uint256 nextEpochToSearch2, uint256[] memory result2) =
            worm.epochsWithNonZeroRewards(0, worm.currentEpoch(), alice, 3);
        assertEq(result2.length, 3);
        assertEq(result2[0], 0);
        assertEq(result2[1], 1);
        assertEq(result2[2], 2);
        assertEq(nextEpochToSearch2, 3);

        (uint256 nextEpochToSearch3, uint256[] memory result3) = worm.epochsWithNonZeroRewards(0, 100, alice, 10);
        assertEq(result3.length, 3);
        assertEq(result3[0], 0);
        assertEq(result3[1], 1);
        assertEq(result3[2], 2);
        assertEq(nextEpochToSearch3, 100);

        (uint256 nextEpochToSearch4, uint256[] memory result4) = worm.epochsWithNonZeroRewards(100, 100, alice, 10);
        assertEq(result4.length, 0);
        assertEq(nextEpochToSearch4, 200);

        (uint256 nextEpochToSearch5, uint256[] memory result5) =
            worm.epochsWithNonZeroRewards(100, worm.currentEpoch(), alice, 10);
        assertEq(result5.length, 3);
        assertEq(result5[0], 52560);
        assertEq(result5[1], 52561);
        assertEq(result5[2], 52562);
        assertEq(nextEpochToSearch5, worm.currentEpoch() + 100);
    }
}
