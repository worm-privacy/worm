// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Unwrap is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice 1:1 wrapper-token which can be redeemed with actual token
    IERC20 public wrapperToken;

    /// @notice ERC20 token distributed by this contract.
    IERC20 public token;

    constructor(IERC20 _token, IERC20 _wrapperToken) {
        token = _token;
        wrapperToken = _wrapperToken;
    }

    /**
     * @notice Redeem `wrapperToken` for the underlying `token` at 1:1 ratio.
     * @param amount Amount of wrapperToken to redeem.
     */
    function unwrap(uint256 amount) external nonReentrant {
        // Transfer wrapperToken from user to contract
        wrapperToken.safeTransferFrom(msg.sender, address(this), amount);

        // Transfer underlying token to user
        token.safeTransfer(msg.sender, amount);
    }
}
