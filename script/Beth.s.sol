// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BETH} from "../src/BETH.sol";
import {WORM} from "../src/WORM.sol";
import {Staking, IRewardPool} from "../src/Staking.sol";
import {ProofOfBurnVerifier} from "../src/ProofOfBurnVerifier.sol";
import {SpendVerifier} from "../src/SpendVerifier.sol";
import {IVerifier} from "../src/IVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BETHScript is Script {
    BETH public beth;
    WORM public worm;
    Staking public staking;

    function setUp() public {}

    function run(address _premineAddress, uint256 _bethPremine, uint256 _wormPremine) public {
        vm.startBroadcast();

        IVerifier proofOfBurnVerifier = new ProofOfBurnVerifier();
        IVerifier spendVeifier = new SpendVerifier();

        beth = new BETH(proofOfBurnVerifier, spendVeifier, _premineAddress, _bethPremine);
        worm = new WORM(IERC20(beth), _premineAddress, _wormPremine);
        staking = new Staking(IERC20(worm), IERC20(beth));
        beth.initRewardPool(IRewardPool(staking));
        console.log("BETH", address(beth));
        console.log("WORM", address(worm));
        console.log("Staking", address(staking));

        vm.stopBroadcast();
    }
}
