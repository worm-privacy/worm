// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Distributor} from "./Distributor.sol";

contract StaticDistributor is Distributor {
    constructor(IERC20 _token, uint256 _deadlineTimestamp, Share[] memory _shares)
        Distributor(_token, _deadlineTimestamp)
    {
        token = _token;
        for (uint256 i = 0; i < _shares.length; i++) {
            Share memory share = _shares[i];
            require(share.owner != address(0), "Share has no owner!");
            require(shares[share.id].owner == address(0), "Share already revealed!");
            shares[share.id] = share;
        }
    }
}
