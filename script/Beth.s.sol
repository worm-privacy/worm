// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";
import {ProofOfBurnVerifier} from "../src/ProofOfBurnVerifier.sol";
import {SpendVerifier} from "../src/SpendVerifier.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BETHScript is Script {
    BETH public beth;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        uint256 startingTimestamp = block.timestamp;

        address eip7503DotEth = 0x8DC77b145d7009752D6947B3CF6D983caFA1C0Bb;

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();
        beth = new BETH(proofOfBurnVerifier, spendVeifier, eip7503DotEth, 10 ether, eip7503DotEth);

        console.log("BETH", address(beth));

        vm.stopBroadcast();
    }
}
