// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ICOWORM.sol";

contract RestrictedERC20Test is Test {
    ICOWORM token;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        token = new ICOWORM();
    }

    /*//////////////////////////////////////////////////////////////
                            BASIC TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialSupplyMintedToOwner() public {
        assertEq(token.balanceOf(owner), 1_170_335.414128736795616549 ether);
    }

    function testOwnerIsAllowedByDefault() public {
        assertTrue(token.isAllowed(owner));
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFER RESTRICTIONS
    //////////////////////////////////////////////////////////////*/

    function testAllowedSenderCanTransfer() public {
        token.transfer(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function testNonAllowedSenderCannotTransfer() public {
        token.transfer(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert("Sender not allowed to transfer");
        token.transfer(bob, 10 ether);
    }

    function testOwnerCanWhitelist() public {
        token.allowSender(alice);
        assertTrue(token.isAllowed(alice));
    }

    function testOwnerCanRemoveWhitelist() public {
        token.allowSender(alice);
        token.removeSender(alice);

        assertFalse(token.isAllowed(alice));
    }

    function testWhitelistedAddressCanTransfer() public {
        token.transfer(alice, 100 ether);

        token.allowSender(alice);

        vm.prank(alice);
        token.transfer(bob, 50 ether);

        assertEq(token.balanceOf(bob), 50 ether);
    }

    function testRemovedAddressCannotTransfer() public {
        token.transfer(alice, 100 ether);
        token.allowSender(alice);
        token.removeSender(alice);

        vm.prank(alice);
        vm.expectRevert("Sender not allowed to transfer");
        token.transfer(bob, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSFERFROM RESTRICTION
    //////////////////////////////////////////////////////////////*/

    function testTransferFromRespectsRestriction() public {
        token.transfer(alice, 100 ether);

        vm.prank(alice);
        token.approve(charlie, 100 ether);

        vm.prank(charlie);
        vm.expectRevert("Sender not allowed to transfer");
        token.transferFrom(alice, bob, 10 ether);
    }

    function testTransferFromWorksIfSenderWhitelisted() public {
        token.transfer(alice, 100 ether);
        token.allowSender(alice);

        vm.prank(alice);
        token.approve(charlie, 100 ether);

        vm.prank(charlie);
        token.transferFrom(alice, bob, 10 ether);

        assertEq(token.balanceOf(bob), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function testNonOwnerCannotWhitelist() public {
        vm.prank(alice);
        vm.expectRevert();
        token.allowSender(alice);
    }

    function testNonOwnerCannotRemoveWhitelist() public {
        vm.prank(alice);
        vm.expectRevert();
        token.removeSender(owner);
    }
}
