// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Beth} from "../src/Beth.sol";

contract BethScript is Script {
    Beth public beth;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        beth = new Beth();

        vm.stopBroadcast();
    }
}
