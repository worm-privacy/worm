// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {DynamicDistributor} from "../src/distributors/DynamicDistributor.sol";
import {Distributor} from "../src/distributors/Distributor.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract DynamicDistributorTest is Test {
    using MessageHashUtils for bytes32;

    ERC20Mock token;
    DynamicDistributor distributor;

    uint256 masterPk;
    address master;

    uint256 constant START = 1_000;
    uint256 constant DEADLINE = 10_000;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new ERC20Mock();

        masterPk = 0xBEEF;
        master = vm.addr(masterPk);

        distributor = new DynamicDistributor(token, DEADLINE, master);

        token.mint(address(distributor), 10_000 ether);
    }

    function _signShare(Distributor.Share memory share) internal view returns (bytes memory) {
        bytes memory encoded = abi.encode(share);
        bytes32 hash = keccak256(encoded).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(masterPk, hash);
        return abi.encodePacked(r, s, v);
    }

    function test_DeadlineBlocksClaims() public {
        vm.warp(DEADLINE + 1);

        Distributor.Share memory emptyShare;
        vm.expectRevert("Reveal period has ended!");
        distributor.reveal(emptyShare, "");
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
        (, address owner,,,,,) = distributor.shares(1);
        assertEq(owner, alice);
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

        vm.warp(START + 50);

        vm.prank(alice);
        distributor.trigger(1);

        assertEq(token.balanceOf(alice), 150 ether);

        vm.prank(alice);
        distributor.changeOwner(1, bob);

        vm.prank(alice);
        vm.expectRevert("You are not the share owner!");
        distributor.trigger(1);

        assertEq(token.balanceOf(bob), 0 ether);
        vm.warp(START + 100);
        vm.prank(bob);
        distributor.trigger(1);
        assertEq(token.balanceOf(bob), 50 ether);

        vm.warp(START + 1000);
        vm.prank(bob);
        vm.expectRevert("Nothing to claim!");
        distributor.trigger(1);
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
