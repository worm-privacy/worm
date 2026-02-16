// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/hooks/cypher-eth/BETHToETH.sol";
import {IWNativeToken} from "src/hooks/cypher-eth/IWNativeToken.sol";

contract DeployBETHToETH is Script {
    // mainnet addresses
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant BETH = 0x5624344235607940d4d4EE76Bf8817d403EB9Cf8;
    address constant swapRouter = 0x20C5893f69F635f55b0367C519F3f95e59c0b0Ab;

    function run() external {
        vm.startBroadcast();

        BETHToETH bethToEth = new BETHToETH(IERC20(BETH), IWNativeToken(WETH), ISwapRouter(swapRouter));

        console.log("BETHToETH deployed to:", address(bethToEth));
        console.log("BETH address:", BETH);
        console.log("WETH address:", WETH);

        vm.stopBroadcast();
    }
}
