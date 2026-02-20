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

    uint256 constant PREMINE = 5851677.070643683978082748 ether;

    function setUp() public {}

    function newNonVested(uint256 id, address owner, uint256 amount) internal pure returns (Distributor.Share memory) {
        return Distributor.Share({
            id: id, owner: owner, tge: amount, startTime: 0, initialAmount: 0, amountPerSecond: 0, totalCap: amount
        });
    }

    function newVested(
        uint256 id,
        address owner,
        uint256 tgeBips,
        uint256 amount,
        uint256 blockTimestamp,
        uint256 cliffPeriodInMonths,
        uint256 vestingInMonths
    ) internal pure returns (Distributor.Share memory) {
        require(tgeBips <= 10000, "TGE should be in basis points");
        require(cliffPeriodInMonths <= vestingInMonths, "Cliff period incorrect");
        uint256 startTime = blockTimestamp + (cliffPeriodInMonths * 4 weeks);
        uint256 tgeAmount = amount * tgeBips / 10000;
        uint256 amountAfterTge = amount - tgeAmount;
        uint256 initialAmount = amountAfterTge * cliffPeriodInMonths / vestingInMonths;
        uint256 amountPerSecond = (amountAfterTge - initialAmount) / ((vestingInMonths - cliffPeriodInMonths) * 30 days);
        return Distributor.Share({
            id: id,
            owner: owner,
            tge: tgeAmount,
            startTime: startTime,
            initialAmount: initialAmount,
            amountPerSecond: amountPerSecond,
            totalCap: amount
        });
    }

    function ofPremine(uint256 bipsA, uint256 bipsB) internal pure returns (uint256) {
        return PREMINE * bipsA * bipsB / 100_000_000;
    }

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
