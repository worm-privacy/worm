// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";
import {WORM} from "../src/WORM.sol";
import {Staking} from "../src/Staking.sol";
import {DynamicDistributor} from "../src/distributors/DynamicDistributor.sol";
import {ProofOfBurnVerifier} from "../src/ProofOfBurnVerifier.sol";
import {SpendVerifier} from "../src/SpendVerifier.sol";
import {IVerifier} from "../src/interfaces/IVerifier.sol";
import {IRewardPool} from "../src/interfaces/IRewardPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FakePool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        console.log(recipient);
        console.log(zeroForOne);
        console.log(amountSpecified);
        console.log(sqrtPriceLimitX96);
        amount0 = 0;
        amount1 = 0;
    }
}

contract DeployAnvilScript is Script {
    BETH public beth;
    WORM public worm;
    Staking public staking;
    DynamicDistributor public dist;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        uint256 startingTimestamp = block.timestamp;

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();

        uint256 premineAmount = 40000 ether;
        beth = new BETH(proofOfBurnVerifier, spendVeifier, msg.sender, 1000 ether, msg.sender);
        worm = new WORM(IERC20(beth), msg.sender, premineAmount, startingTimestamp);
        staking = new Staking(IERC20(worm), IERC20(beth), 1 days, startingTimestamp);
        beth.initRewardPool(IRewardPool(staking));

        dist = new DynamicDistributor(IERC20(worm), UINT256_MAX, 0xf7d5E3D3546ebf28bDfC55cfceb0E62462E16C05);
        worm.transfer(address(dist), 20000 ether);
        worm.transfer(address(0x4CFD0573feDe55f980724373469A32dd7a1619c5), 20000 ether);
        worm.transfer(address(0x4CFD0573feDe55f980724373469A32dd7a1619c5), 1000 ether);

        console.log("BETH", address(beth));
        console.log("WORM", address(worm));
        console.log("Staking", address(staking));
        console.log("Dynamic Distributor", address(dist));

        vm.stopBroadcast();
    }
}
