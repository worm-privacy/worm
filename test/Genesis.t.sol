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

    uint256 masterKey = 0xABCD;
    address master = vm.addr(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        vm.warp(123456);

        token = new MockToken();
        genesis = new Genesis(master, IERC20(token));

        // Fund contract with tokens
        token.mint(address(genesis), 1_000_000 ether);
    }

    function _signShare(Genesis.Share memory share, uint256 privKey) internal returns (bytes memory) {
        bytes memory abiShare = abi.encode(share);
        bytes32 hash = keccak256(abiShare).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, hash);
        return abi.encodePacked(r, s, v);
    }
}
