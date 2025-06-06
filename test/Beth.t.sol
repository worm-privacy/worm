// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Beth} from "../src/Beth.sol";

contract BethTest is Test {
    Beth public beth;

    function setUp() public {
        beth = new Beth();
    }

    function test_something() public {

    }
}
