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

        address eip7503DotEth = 0x8DC77b145d7009752D6947B3CF6D983caFA1C0Bb;
        address keyvankDotEth = 0x372abb165e3283c4e71ce68efba2934fea5bff45;

        uint256 numStaticShares = 6;
        Distributor.Share[] memory staticShares = new Distributor.Share[](numStaticShares);

        staticShares[0] = Distributor.Share({
            id: 0,
            owner: eip7503DotEth,
            tge: 1000 ether,
            startTime: 0,
            initialAmount: 0,
            amountPerSecond: 0,
            totalCap: 1000 ether
        });

        // Team member #1
        staticShares[1] = Distributor.Share({
            id: 1,
            owner: eip7503DotEth,
            tge: 1000 ether,
            startTime: 0,
            initialAmount: 0,
            amountPerSecond: 0,
            totalCap: 1000 ether
        });

        // Team member #2
        staticShares[2] = Distributor.Share({
            id: 2,
            owner: eip7503DotEth,
            tge: 1000 ether,
            startTime: 0,
            initialAmount: 0,
            amountPerSecond: 0,
            totalCap: 1000 ether
        });

        // Team member #3
        staticShares[3] = Distributor.Share({
            id: 3,
            owner: eip7503DotEth,
            tge: 1000 ether,
            startTime: 0,
            initialAmount: 0,
            amountPerSecond: 0,
            totalCap: 1000 ether
        });

        // Private investor
        staticShares[4] = Distributor.Share({
            id: 4,
            owner: eip7503DotEth,
            tge: 1000 ether,
            startTime: block.timestamp + (6 * 4 weeks),
            initialAmount: 0,
            amountPerSecond: 0,
            totalCap: 1000 ether
        });

        // Foundation
        staticShares[5] = Distributor.Share({
            id: 5,
            owner: eip7503DotEth,
            tge: 1000 ether,
            startTime: block.timestamp + (3 * 4 weeks),
            initialAmount: 0,
            amountPerSecond: 0,
            totalCap: 1000 ether
        });

        uint256 staticsPremine = 0;
        for (uint256 i = 0; i < numStaticShares; i++) {
            staticsPremine += staticShares[i].totalCap;
        }
        uint256 dynamicsPremine = 100 ether;

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();
        beth = new BETH(proofOfBurnVerifier, spendVeifier, eip7503DotEth, 0);
        worm = new WORM(IERC20(beth), msg.sender, staticsPremine + dynamicsPremine);
        staking = new Staking(IERC20(worm), IERC20(beth));
        beth.initRewardPool(IRewardPool(staking));

        StaticDistributor staticDist = new StaticDistributor(IERC20(worm), UINT256_MAX, staticShares);
        worm.transfer(address(staticDist), staticsPremine);

        DynamicDistributor dynamicDist =
            new DynamicDistributor(IERC20(worm), block.timestamp + (3 * 4 weeks), address(0xa11ce));
        worm.transfer(address(dynamicDist), dynamicsPremine);

        console.log("BETH", address(beth));
        console.log("WORM", address(worm));
        console.log("Staking", address(staking));

        vm.stopBroadcast();
    }
}
