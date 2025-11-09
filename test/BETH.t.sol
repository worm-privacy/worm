// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BETH} from "../src/BETH.sol";
import {WORM} from "../src/WORM.sol";
import {IVerifier} from "../src/IVerifier.sol";
import {Staking} from "../src/Staking.sol";

contract AlwaysVerify is IVerifier {
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[1] calldata _pubSignals
    ) external returns (bool) {
        return true;
    }
}

contract BETHTest is Test {
    BETH public beth;
    WORM public worm;
    Staking public rewardPool;
    address alice = address(0xa11ce);
    address bob = address(0xb0b);

    function setUp() public {
        beth = new BETH(new AlwaysVerify(), new AlwaysVerify(), address(0), 0);
        worm = new WORM(beth, alice, 10 ether);
        rewardPool = new Staking(worm, beth);
        beth.initRewardPool(rewardPool);
    }

    function test_mint() public {
        assertEq(worm.balanceOf(alice), 10 ether);
        beth.mintCoin(
            [uint256(0), uint256(0)],
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
            [uint256(0), uint256(0)],
            block.number - 1,
            123,
            234,
            0.1 ether,
            1 ether,
            alice,
            0.2 ether,
            bob,
            new bytes(0),
            new bytes(0)
        );
        assertEq(beth.balanceOf(alice), 1 ether - 0.1 ether - 0.2 ether - (1 ether / 200));
        assertEq(beth.totalSupply(), 1 ether);
        assertEq(beth.balanceOf(address(this)), 0.1 ether);
        assertEq(beth.balanceOf(bob), 0.2 ether);
        assertEq(beth.balanceOf(address(rewardPool)), (1 ether / 200));
    }

    function test_spend() public {
        assertEq(worm.balanceOf(alice), 10 ether);
        beth.mintCoin(
            [uint256(0), uint256(0)],
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
            [uint256(0), uint256(0)],
            block.number - 1,
            123,
            234,
            0.1 ether,
            1 ether,
            alice,
            0.2 ether,
            bob,
            new bytes(0),
            new bytes(0)
        );
        beth.spendCoin(
            [uint256(0), uint256(0)],
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]],
            [uint256(0), uint256(0)],
            234,
            1 ether,
            456,
            0.23 ether,
            bob
        );
        assertEq(beth.totalSupply(), 1 ether + 1 ether);
        assertEq(beth.balanceOf(address(this)), 0.33 ether);
        assertEq(beth.balanceOf(bob), 0.2 ether + 0.765 ether);
        assertEq(beth.balanceOf(address(rewardPool)), 2 * (1 ether / 200));
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
