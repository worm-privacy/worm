// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BETH} from "../src/BETH.sol";

contract BETHTest is Test {
    BETH public beth;

    function setUp() public {
        beth = new BETH();
    }

    function test_something() public {}
}
