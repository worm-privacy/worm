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
import {Distributor, newVested} from "../src/distributors/Distributor.sol";
import {StaticDistributor} from "../src/distributors/StaticDistributor.sol";
import {DynamicDistributor} from "../src/distributors/DynamicDistributor.sol";

contract BETHScript is Script {
    BETH public beth;
    WORM public worm;
    Staking public staking;

    uint256 constant PREMINE = 5851677.070643683978082748 ether;

    function setUp() public {}

    function ofPremine(uint256 bipsA, uint256 bipsB) internal pure returns (uint256) {
        return PREMINE * bipsA * bipsB / 100_000_000;
    }

    function run() public {
        vm.startBroadcast();

        uint256 startingTimestamp = 1771855200; // 23 Feb 2PM UTC

        address bethMainnet = 0x5624344235607940d4d4EE76Bf8817d403EB9Cf8;
        address eip7503DotEth = 0x8DC77b145d7009752D6947B3CF6D983caFA1C0Bb;
        address keyvankDotEth = 0x372abB165e3283C4E71ce68eFBA2934FEA5bFF45;

        uint256 numStaticShares = 9;
        Distributor.Share[] memory staticShares = new Distributor.Share[](numStaticShares);

        uint256 lpIcoTotal = ofPremine(4000, 10000);

        // Team member #1
        staticShares[0] = newVested(1, keyvankDotEth, 0, ofPremine(2400, 9000), startingTimestamp, 6, 36);
        // Team member #2
        staticShares[1] = newVested(
            2, address(0xBF44aa57e71a9dBa931058064438876AC7841bfa), 0, ofPremine(2400, 425), startingTimestamp, 6, 36
        );
        // Team member #3
        staticShares[2] = newVested(3, eip7503DotEth, 0, ofPremine(2400, 300), startingTimestamp, 6, 36);
        // Team member #4
        staticShares[3] = newVested(
            4, address(0x82C11504D17E26653214741f93e8400F15f88B13), 0, ofPremine(2400, 200), startingTimestamp, 6, 36
        );
        // Team member #5
        staticShares[4] = newVested(5, eip7503DotEth, 0, ofPremine(2400, 50), startingTimestamp, 6, 36);
        // Team member #6
        staticShares[5] = newVested(6, eip7503DotEth, 0, ofPremine(2400, 25), startingTimestamp, 6, 36);

        // Advisors
        staticShares[6] = newVested(7, eip7503DotEth, 0, ofPremine(100, 10000), startingTimestamp, 6, 36);

        // Private investor
        staticShares[7] = newVested(
            8, address(0x3693c57508606cC7f26b7Db3827a8eCebC628c66), 0, ofPremine(800, 10000), startingTimestamp, 6, 36
        );

        // Foundation treasury
        staticShares[8] = newVested(9, eip7503DotEth, 500, ofPremine(1200, 10000), startingTimestamp, 3, 36);

        uint256 staticsPremine = 0;
        for (uint256 i = 0; i < numStaticShares; i++) {
            staticsPremine += staticShares[i].totalCap;
        }
        uint256 dynamicsPremine = PREMINE - staticsPremine - lpIcoTotal;

        require(877751 ether <= dynamicsPremine && dynamicsPremine <= 877752 ether, "Dynamics premine not in range!");

        StaticDistributor staticDist = new StaticDistributor(IERC20(worm), staticShares);
        DynamicDistributor dynamicDist =
            new DynamicDistributor(IERC20(worm), startingTimestamp + (3 * 30 days), address(0xa11ce));

        vm.stopBroadcast();
    }
}
