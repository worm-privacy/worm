// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

contract SwapProxy {
    IUniversalRouter public universalRouter;
    IERC20 beth;

    constructor(IERC20 _beth, IUniversalRouter _universalRouter) {
        beth = _beth;
        universalRouter = _universalRouter;
    }

    function execute(address from, uint256 amount, bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
    {
        require(beth.transferFrom(from, address(universalRouter), amount), "TF");
        universalRouter.execute(commands, inputs, deadline);
    }
}
