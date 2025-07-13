// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BETH} from "../src/BETH.sol";

contract BETHTest is Test {
    BETH public beth;

    function setUp() public {
        beth = new BETH();
    }

    function test_proof_of_burn_public_commitment() public pure {
        assertEq(
            uint256(
                keccak256(
                    abi.encodePacked(
                        uint256(59143423853376781417125983618613228280659999960210986093114662880508950626056),
                        uint256(6440986494580578507067062322918826161607249544152625345271923997131881196551),
                        uint256(17037121386624115832741779956926083357970021470596072423532449206176480530268),
                        uint256(123),
                        uint256(234),
                        uint256(827641930419614124039720421795580660909102123457)
                    )
                ) >> 8
            ),
            uint256(357580174033218738890059651196032050606164050021517478600256431899986052418)
        );
    }
}
