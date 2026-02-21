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

contract BETHScript is Script {
    BETH public beth;
    WORM public worm;
    Staking public staking;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address bethMainnet = 0x5624344235607940d4d4EE76Bf8817d403EB9Cf8;
        address stakingMainnet = 0x03d4702b51a98661B89dF5fcBe8C4baeF84C60B7;

        beth = BETH(bethMainnet);
        staking = Staking(stakingMainnet);

        (bool success, bytes memory data) =
            address(beth).delegatecall(abi.encodeWithSignature("initRewardPool(address)", staking));

        console.log("Done");

        vm.stopBroadcast();
    }
}
