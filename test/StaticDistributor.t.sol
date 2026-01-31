// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {StaticDistributor} from "../src/distributors/StaticDistributor.sol";
import {Distributor} from "../src/distributors/Distributor.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract StaticDistributorTest is Test {
    ERC20Mock token;
    StaticDistributor distributor;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint256 constant START = 1_000;
    uint256 constant DEADLINE = 10_000;

    function setUp() public {
        token = new ERC20Mock();

        Distributor.Share[] memory shares = new Distributor.Share[](1);
        shares[0] = Distributor.Share({
            id: 1,
            owner: alice,
            tge: 100 ether,
            startTime: START,
            initialAmount: 200 ether,
            amountPerSecond: 1 ether,
            totalCap: 1_000 ether
        });

        distributor = new StaticDistributor(token, DEADLINE, shares);

        token.mint(address(distributor), 1_000 ether);
    }

    function test_TGEOnlyBeforeStart() public {
        vm.warp(START - 1);

        uint256 claimable = distributor.calculateClaimable(1);
        assertEq(claimable, 100 ether);
    }

    function test_LinearVestingAfterStart() public {
        vm.warp(START + 100);

        uint256 claimable = distributor.calculateClaimable(1);
        // tge + initial + 100 seconds
        assertEq(claimable, 100 ether + 200 ether + 100 ether);
    }

    function test_TriggerTransfersTokens() public {
        vm.warp(START + 10);

        vm.prank(alice);
        distributor.trigger(1);

        assertEq(token.balanceOf(alice), 310 ether);
    }

    function test_OnlyTheShareOwnerCanClaim() public {
        vm.warp(START + 5);

        // Bob can not trigger Alice’s claim
        vm.prank(bob);
        vm.expectRevert("You are not the share owner!");
        distributor.trigger(1);
    }

    function test_CannotDoubleClaimSameTime() public {
        vm.warp(START + 10);

        vm.prank(alice);
        distributor.trigger(1);

        vm.prank(alice);
        vm.expectRevert("Nothing to claim!");
        distributor.trigger(1);
    }

    function test_ClaimCapsAtTotalCap() public {
        vm.warp(START + 8_999);

        vm.prank(alice);
        distributor.trigger(1);

        assertEq(token.balanceOf(alice), 1_000 ether);
    }

    function test_DeadlineBlocksClaims() public {
        vm.warp(DEADLINE + 1);

        vm.expectRevert("Distribution has eneded!");
        distributor.trigger(1);
    }

    function test_ChangeOwner() public {
        vm.prank(alice);
        distributor.changeOwner(1, bob);

        vm.warp(START + 1);
        vm.prank(bob);
        distributor.trigger(1);

        assertGt(token.balanceOf(bob), 0);
    }

    function test_NonOwnerCannotChangeOwner() public {
        vm.prank(bob);
        vm.expectRevert("You are not the share owner!");
        distributor.changeOwner(1, bob);
    }
}
