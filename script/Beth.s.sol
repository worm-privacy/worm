// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";

contract BETHScript is Script {
    BETH public beth;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        beth = new BETH();

        vm.stopBroadcast();
    }
}
