// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";
import {WORM} from "../src/WORM.sol";
import {Staking} from "../src/Staking.sol";
import {ProofOfBurnVerifier} from "../src/ProofOfBurnVerifier.sol";
import {SpendVerifier} from "../src/SpendVerifier.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {IRewardPool} from "../src/interfaces/IRewardPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Distributor} from "../src/distributors/Distributor.sol";
import {StaticDistributor} from "../src/distributors/StaticDistributor.sol";
import {DynamicDistributor} from "../src/distributors/DynamicDistributor.sol";

contract WormScript is Script {
    BETH public beth;
    WORM public worm;
    Staking public staking;

    uint256 constant PREMINE = 5851677.070643683978082748 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        uint256 startingTimestamp = 1771855200; // 23 Feb 2PM UTC

        address bethMainnet = 0x5624344235607940d4d4EE76Bf8817d403EB9Cf8;
        address eip7503DotEth = 0x8DC77b145d7009752D6947B3CF6D983caFA1C0Bb;

        beth = BETH(bethMainnet);

        worm = new WORM(IERC20(beth), eip7503DotEth, PREMINE, startingTimestamp);
        require(worm.balanceOf(eip7503DotEth) == PREMINE, "Invalid WORM amount minted for deployer!");

        staking = new Staking(IERC20(worm), IERC20(beth), 7 days, startingTimestamp);

        console.log("WORM", address(worm));
        console.log("Staking", address(staking));

        vm.stopBroadcast();
    }
}
