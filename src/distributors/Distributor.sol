// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Distributor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event OwnerChanged(uint256 shareId, address oldOwner, address newOwner);
    event Triggered(uint256 shareId, uint256 amountReleased);

    /// @notice ERC20 token distributed by this contract.
    IERC20 public token;

    /// @notice Timestamp after which no tokens can be released.
    uint256 public deadlineTimestamp;

    struct Share {
        uint256 id; // Unique identifier for the share
        address owner; // Address that can claim this share's emissions
        uint256 tge; // Amount claimable right after reveal
        uint256 startTime; // Timestamp when share starts
        uint256 initialAmount; // Amount of token immediately released
        uint256 amountPerSecond; // Amount of token generated per second
        uint256 totalCap; // Maximum total amount that can ever be claimed
    }

    /// @notice Stores all revealed shares by ID.
    mapping(uint256 => Share) public shares;

    /// @notice Tracks how much has already been claimed for each share.
    mapping(uint256 => uint256) public shareClaimed;

    constructor(IERC20 _token, uint256 _deadlineTimestamp) {
        deadlineTimestamp = _deadlineTimestamp;
        token = _token;
    }

    /**
     * @notice Computes the total tokens that should be claimable for a share at the current time.
     * @param _shareId ID of the share.
     * @return claimable Total amount that *should* have been emitted so far.
     */
    function calculateClaimable(uint256 _shareId) public view returns (uint256) {
        Share storage share = shares[_shareId];
        uint256 claimable = share.tge;
        if (block.timestamp >= share.startTime) {
            claimable += share.initialAmount;
            claimable += share.amountPerSecond * (block.timestamp - share.startTime);
        }
        return Math.min(claimable, share.totalCap);
    }

    /**
     * @notice Changes the owner of a share.
     * @param _shareId ID of the share.
     * @param _newOwner Address of the new owner.
     */
    function changeOwner(uint256 _shareId, address _newOwner) external {
        require(block.timestamp < deadlineTimestamp, "Deadline!");
        Share storage share = shares[_shareId];
        require(msg.sender == share.owner, "You are not the share owner!");
        share.owner = _newOwner;
        emit OwnerChanged(_shareId, msg.sender, _newOwner);
    }

    /**
     * @notice Claims any unclaimed portion of a share’s emission.
     * @param _shareId Share identifier.
     */
    function trigger(uint256 _shareId) external nonReentrant {
        require(block.timestamp < deadlineTimestamp, "Distribution has eneded!");
        require(msg.sender == shares[_shareId].owner, "You are not the share owner!");

        Share storage share = shares[_shareId];

        uint256 claimable = calculateClaimable(_shareId);

        require(claimable <= share.totalCap, "Claim malfunction!");
        require(claimable > shareClaimed[_shareId], "Nothing to claim!");

        uint256 amount = claimable - shareClaimed[_shareId];
        shareClaimed[_shareId] += amount;
        require(shareClaimed[_shareId] <= share.totalCap, "Can't claim more than total!");

        token.safeTransfer(share.owner, amount);

        emit Triggered(_shareId, amount);
    }
}
