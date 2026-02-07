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

        uint256 startingTimestamp = block.timestamp;

        address eip7503DotEth = 0x8DC77b145d7009752D6947B3CF6D983caFA1C0Bb;
        address keyvankDotEth = 0x372abB165e3283C4E71ce68eFBA2934FEA5bFF45;

        uint256 numStaticShares = 7;
        Distributor.Share[] memory staticShares = new Distributor.Share[](numStaticShares);

        staticShares[0] = newNonVested(0, eip7503DotEth, ofPremine(4000, 10000)); // 40% LP/ICO

        // Team member #1
        staticShares[1] = newVested(1, keyvankDotEth, 0, ofPremine(2400, 8000), block.timestamp, 6, 36);
        // Team member #2
        staticShares[2] = newVested(2, keyvankDotEth, 0, ofPremine(2400, 1000), block.timestamp, 6, 36);
        // Team member #2
        staticShares[3] = newVested(3, keyvankDotEth, 0, ofPremine(2400, 1000), block.timestamp, 6, 36);

        // Advisors
        staticShares[4] = newVested(4, eip7503DotEth, 0, ofPremine(100, 10000), block.timestamp, 6, 36);

        // Private investor
        staticShares[5] = newVested(5, eip7503DotEth, 0, ofPremine(800, 10000), block.timestamp, 6, 36);

        // Foundation treasury
        staticShares[6] = newVested(6, eip7503DotEth, 50, ofPremine(1200, 10000), block.timestamp, 3, 36);

        uint256 staticsPremine = 0;
        for (uint256 i = 0; i < numStaticShares; i++) {
            staticsPremine += staticShares[i].totalCap;
        }
        uint256 dynamicsPremine = PREMINE - staticsPremine;

        require(877751 ether <= dynamicsPremine && dynamicsPremine <= 877752 ether, "Dynamics premine not in range!");

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();
        beth = new BETH(proofOfBurnVerifier, spendVeifier, eip7503DotEth, 0);

        require(staticsPremine + dynamicsPremine == PREMINE, "Invalid premine!");
        worm = new WORM(IERC20(beth), msg.sender, staticsPremine + dynamicsPremine, startingTimestamp, 0);
        require(worm.balanceOf(msg.sender) == PREMINE, "Invalid WORM amount minted for deployer!");

        staking = new Staking(IERC20(worm), IERC20(beth), 7 days, startingTimestamp);
        beth.initRewardPool(IRewardPool(staking));

        StaticDistributor staticDist = new StaticDistributor(IERC20(worm), staticShares);
        worm.transfer(address(staticDist), staticsPremine);
        require(worm.balanceOf(address(staticDist)) == staticsPremine, "Invalid WORM balance for static distributor!");
        require(
            worm.balanceOf(msg.sender) == PREMINE - staticsPremine,
            "Invalid WORM balance after transfer to static distributor!"
        );

        DynamicDistributor dynamicDist =
            new DynamicDistributor(IERC20(worm), block.timestamp + (3 * 30 days), address(0xa11ce));
        worm.transfer(address(dynamicDist), dynamicsPremine);
        require(worm.balanceOf(address(dynamicDist)) == dynamicsPremine, "Invalid WORM balance for static distributor!");
        require(worm.balanceOf(msg.sender) == 0, "Invalid WORM balance after transfer to dynamic distributor!");

        require(worm.totalSupply() == PREMINE, "Invalid WORM total supply!");

        console.log("BETH", address(beth));
        console.log("WORM", address(worm));
        console.log("Staking", address(staking));

        vm.stopBroadcast();
    }
}
