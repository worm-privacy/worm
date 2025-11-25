// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Test, console} from "forge-std/Test.sol";
import {Genesis} from "../src/Genesis.sol";
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

contract GenesisTest is Test {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    Genesis genesis;
    MockToken token;
    MockToken wrapperToken;

    uint256 masterKey = 0xABCD;
    address master = vm.addr(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        vm.warp(123456);

        token = new MockToken();
        wrapperToken = new MockToken();
        genesis = new Genesis(master, IERC20(token), IERC20(wrapperToken));

        // Fund contract with tokens
        token.mint(address(genesis), 1_000_000 ether);
        wrapperToken.mint(user, 100 ether);
    }

    function _signShare(Genesis.Share memory share, uint256 privKey) internal returns (bytes memory) {
        bytes memory abiShare = abi.encode(share);
        bytes32 hash = keccak256(abiShare).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, hash);
        return abi.encodePacked(r, s, v);
    }

    function testRevealAndTriggerSharpEmission() public {
        // Create a share with a sharp emission
        Genesis.SharpEmission[] memory sharp = new Genesis.SharpEmission[](1);
        sharp[0] = Genesis.SharpEmission(block.timestamp - 10, 100 ether);

        Genesis.LinearEmission memory linear = Genesis.LinearEmission(0, 0, 0);

        Genesis.Share memory share =
            Genesis.Share({id: 1, owner: user, sharpEmissions: sharp, linearEmission: linear, totalCap: 100 ether});

        // Use a private key corresponding to master for testing

        bytes memory sig = _signShare(share, masterKey);

        // Cheat to set master private key
        vm.prank(master);
        genesis.reveal(share, sig);

        // Trigger claim
        vm.prank(user);
        genesis.trigger(1);

        // Check balance
        assertEq(token.balanceOf(user), 100 ether);
        assertEq(genesis.shareClaimed(1), 100 ether);
    }

    function testLinearEmission() public {
        // Linear emission of 1 ether per second, cap 10 ether
        Genesis.LinearEmission memory linear = Genesis.LinearEmission(block.timestamp - 5, 1 ether, 10 ether);
        Genesis.SharpEmission[] memory sharp;

        Genesis.Share memory share =
            Genesis.Share({id: 2, owner: user, sharpEmissions: sharp, linearEmission: linear, totalCap: 10 ether});

        bytes memory sig = _signShare(share, masterKey);

        vm.prank(master);
        genesis.reveal(share, sig);

        vm.prank(user);
        genesis.trigger(2);
        assertEq(token.balanceOf(user), 5 ether);

        // Trigger after 5 seconds
        vm.warp(block.timestamp + 5);
        vm.prank(user);
        genesis.trigger(2);
        assertEq(token.balanceOf(user), 10 ether);
    }

    function testClaimCannotExceedTotal() public {
        Genesis.SharpEmission[] memory sharp = new Genesis.SharpEmission[](1);
        sharp[0] = Genesis.SharpEmission(block.timestamp - 1, 100 ether);

        Genesis.LinearEmission memory linear = Genesis.LinearEmission(block.timestamp - 1, 50 ether, 50 ether);

        Genesis.Share memory share =
            Genesis.Share({id: 3, owner: user, sharpEmissions: sharp, linearEmission: linear, totalCap: 120 ether});

        bytes memory sig = _signShare(share, masterKey);

        vm.prank(master);
        genesis.reveal(share, sig);

        vm.prank(user);
        genesis.trigger(3);

        // Total claimed should not exceed totalCap
        assertEq(genesis.shareClaimed(3), 120 ether);
        assertEq(token.balanceOf(user), 120 ether);
    }

    function testCannotRevealTwice() public {
        Genesis.SharpEmission[] memory sharp;
        Genesis.LinearEmission memory linear = Genesis.LinearEmission(0, 0, 0);

        Genesis.Share memory share =
            Genesis.Share({id: 4, owner: user, sharpEmissions: sharp, linearEmission: linear, totalCap: 0});

        bytes memory sig = _signShare(share, masterKey);

        vm.prank(master);
        genesis.reveal(share, sig);

        // Reveal again should revert
        vm.prank(master);
        vm.expectRevert("Share already revealed!");
        genesis.reveal(share, sig);
    }

    function testCannotClaimBeforeEmission() public {
        Genesis.SharpEmission[] memory sharp = new Genesis.SharpEmission[](1);
        sharp[0] = Genesis.SharpEmission(block.timestamp + 1000, 100 ether);

        Genesis.LinearEmission memory linear = Genesis.LinearEmission(block.timestamp + 1000, 1 ether, 10 ether);

        Genesis.Share memory share =
            Genesis.Share({id: 5, owner: user, sharpEmissions: sharp, linearEmission: linear, totalCap: 110 ether});

        bytes memory sig = _signShare(share, masterKey);

        vm.prank(master);
        genesis.reveal(share, sig);

        // Cannot claim yet
        vm.prank(user);
        vm.expectRevert("Nothing to claim!");
        genesis.trigger(5);
    }

    function testRedeemWrapperToken() public {
        uint256 redeemAmount = 30 ether;

        // User approves Genesis contract to spend wrapperToken
        vm.prank(user);
        wrapperToken.approve(address(genesis), redeemAmount);

        // Redeem
        vm.prank(user);
        genesis.redeem(redeemAmount);

        // Check balances
        assertEq(wrapperToken.balanceOf(user), 70 ether); // 100 - 30
        assertEq(token.balanceOf(user), redeemAmount); // received 30 token
        assertEq(wrapperToken.balanceOf(address(genesis)), redeemAmount); // Genesis holds redeemed wrapperToken
    }
}
