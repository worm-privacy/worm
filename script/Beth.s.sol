// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";
import {ProofOfBurnVerifier} from "../src/ProofOfBurnVerifier.sol";
import {SpendVerifier} from "../src/SpendVerifier.sol";
import {IVerifier} from "../src/IVerifier.sol";

contract BETHScript is Script {
    BETH public beth;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();
        beth = new BETH(proofOfBurnVerifier, spendVeifier);

        vm.stopBroadcast();
    }
}
