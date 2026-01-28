// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {DynamicDistributor} from "../src/distributors/DynamicDistributor.sol";
import {Distributor} from "../src/distributors/Distributor.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DynamicDistributorTest is Test {
    ERC20Mock token;
    DynamicDistributor distributor;

    uint256 masterPk;
    address master;

    uint256 constant START = 1_000;
    uint256 constant DEADLINE = 10_000;

    address alice = address(0xA11CE);

    function setUp() public {
        token = new ERC20Mock();

        masterPk = 0xBEEF;
        master = vm.addr(masterPk);

        distributor = new DynamicDistributor(
            token,
            DEADLINE,
            master
        );

        token.mint(address(distributor), 10_000 ether);
    }

    function _signShare(Distributor.Share memory share) internal returns (bytes memory) {
        bytes memory encoded = abi.encode(share);
        bytes32 hash = keccak256(encoded).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(masterPk, hash);
        return abi.encodePacked(r, s, v);
    }

    function test_RevealValidShare() public {
        Distributor.Share memory share = Distributor.Share({
            id: 1,
            owner: alice,
            tge: 100 ether,
            startTime: START,
            initialAmount: 0,
            amountPerSecond: 1 ether,
            totalCap: 500 ether
        });

        bytes memory sig = _signShare(share);

        vm.prank(alice);
        distributor.reveal(share, sig);

        Distributor.Share memory stored = distributor.shares(1);
        assertEq(stored.owner, alice);
    }

    function test_RevealFailsWithInvalidSigner() public {
        Distributor.Share memory share = Distributor.Share({
            id: 1,
            owner: alice,
            tge: 0,
            startTime: START,
            initialAmount: 0,
            amountPerSecond: 1 ether,
            totalCap: 100 ether
        });

        // Sign with wrong key
        bytes32 hash = keccak256(abi.encode(share)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1234, hash);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        vm.expectRevert("Not signed by master!");
        distributor.reveal(share, sig);
    }

    function test_RevealOnlyOwnerCanCall() public {
        Distributor.Share memory share = Distributor.Share({
            id: 1,
            owner: alice,
            tge: 0,
            startTime: START,
            initialAmount: 0,
            amountPerSecond: 1 ether,
            totalCap: 100 ether
        });

        bytes memory sig = _signShare(share);

        vm.expectRevert("Only the share owner can reveal!");
        distributor.reveal(share, sig);
    }

    function test_FullClaimFlow() public {
        Distributor.Share memory share = Distributor.Share({
            id: 1,
            owner: alice,
            tge: 50 ether,
            startTime: START,
            initialAmount: 50 ether,
            amountPerSecond: 1 ether,
            totalCap: 200 ether
        });

        bytes memory sig = _signShare(share);

        vm.prank(alice);
        distributor.reveal(share, sig);

        vm.warp(START + 100);

        vm.prank(alice);
        distributor.trigger(1);

        assertEq(token.balanceOf(alice), 200 ether);
    }

    function test_RevealCannotBeCalledTwice() public {
        Distributor.Share memory share = Distributor.Share({
            id: 1,
            owner: alice,
            tge: 0,
            startTime: START,
            initialAmount: 0,
            amountPerSecond: 1 ether,
            totalCap: 100 ether
        });

        bytes memory sig = _signShare(share);

        vm.prank(alice);
        distributor.reveal(share, sig);

        vm.prank(alice);
        vm.expectRevert("Share already revealed!");
        distributor.reveal(share, sig);
    }
}
