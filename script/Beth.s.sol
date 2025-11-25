// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";
import {WORM} from "../src/WORM.sol";
import {Staking} from "../src/Staking.sol";
import {Genesis} from "../src/Genesis.sol";
import {ProofOfBurnVerifier} from "../src/ProofOfBurnVerifier.sol";
import {SpendVerifier} from "../src/SpendVerifier.sol";
import {IVerifier} from "../src/IVerifier.sol";
import {IRewardPool} from "../src/IRewardPool.sol";
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

contract BETHScript is Script {
    BETH public beth;
    WORM public worm;
    Staking public staking;

    Genesis public communityGenesis;
    Genesis public othersGenesis;

    function setUp() public {}

    function run(
        address _bethPremineAddress,
        uint256 _bethPremineAmount,
        uint256 _wormOthersPremineAmount,
        uint256 _wormCommunityPremineAmount,
        address _communityGenesisMaster,
        bool _debug
    ) public {
        vm.startBroadcast();

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();

        beth = new BETH(proofOfBurnVerifier, spendVeifier, _bethPremineAddress, _bethPremineAmount);
        worm = new WORM(IERC20(beth), msg.sender, _wormCommunityPremineAmount + _wormOthersPremineAmount);
        staking = new Staking(IERC20(worm), IERC20(beth));
        beth.initRewardPool(IRewardPool(staking));

        communityGenesis = new Genesis(_communityGenesisMaster, IERC20(worm));
        worm.transfer(address(communityGenesis), _wormCommunityPremineAmount);

        othersGenesis = new Genesis(msg.sender, IERC20(worm));
        worm.transfer(address(othersGenesis), _wormOthersPremineAmount);
        Genesis.Share[] memory shares = new Genesis.Share[](4);
        shares[0] = Genesis.Share({
            id: 0,
            owner: 0x000000000000000000000000000000000000dEaD,
            sharpEmissions: new Genesis.SharpEmission[](0),
            linearEmission: Genesis.LinearEmission(0, 0, 0),
            totalCap: 0 ether
        });
        shares[1] = Genesis.Share({
            id: 1,
            owner: 0x000000000000000000000000000000000000dEaD,
            sharpEmissions: new Genesis.SharpEmission[](0),
            linearEmission: Genesis.LinearEmission(0, 0, 0),
            totalCap: 0 ether
        });
        shares[2] = Genesis.Share({
            id: 2,
            owner: 0x000000000000000000000000000000000000dEaD,
            sharpEmissions: new Genesis.SharpEmission[](0),
            linearEmission: Genesis.LinearEmission(0, 0, 0),
            totalCap: 0 ether
        });
        shares[3] = Genesis.Share({
            id: 3,
            owner: 0x000000000000000000000000000000000000dEaD,
            sharpEmissions: new Genesis.SharpEmission[](0),
            linearEmission: Genesis.LinearEmission(0, 0, 0),
            totalCap: 0 ether
        });
        othersGenesis.revealAndLock(shares);

        console.log("BETH", address(beth));
        console.log("WORM", address(worm));
        console.log("Staking", address(staking));
        FakePool fakePool = new FakePool();
        console.log("Fake pool", address(fakePool));

        vm.stopBroadcast();
    }
}
