// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Genesis is ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    bool public locked;

    /// @notice Address authorized to sign valid Share objects.
    address public master;

    /// @notice ERC20 token distributed by this contract.
    IERC20 public token;

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

    /// @notice Tracks whether a share ID has been revealed (cannot be revealed twice).
    mapping(uint256 => bool) public shareRevealed;

    /// @notice Tracks how much has already been claimed for each share.
    mapping(uint256 => uint256) public shareClaimed;

    /// @notice Emitted when a share is successfully revealed.
    event ShareRevealed(Share share);

    /// @notice Emitted if calculated claimable > total, indicating inconsistent share data.
    event ClaimableMoreThanTotal(uint256 shareId);

    constructor(address _master, IERC20 _token) {
        master = _master;
        token = _token;
    }

    /**
     * @notice Computes the total tokens that should be claimable for a share at the current time.
     * @param _shareId ID of the share.
     * @return owner The owner address of the share.
     * @return claimable Total amount that *should* have been emitted so far.
     * @return total Total cap for this share.
     */
    function calculateClaimable(uint256 _shareId) public view returns (address, uint256, uint256) {
        Share storage share = shares[_shareId];
        uint256 claimable = share.tge;
        if (block.timestamp >= share.startTime) {
            claimable += share.initialAmount;
            claimable += share.amountPerSecond * (block.timestamp - share.startTime);
        }
        claimable = Math.min(claimable, share.totalCap);
        return (share.owner, claimable, share.totalCap);
    }

    /**
     * @notice Reveals a new share by master.
     * @param _shares A list of shares to be added
     */
    function revealAndLock(Share[] calldata _shares) external {
        require(!locked, "Locked!");
        require(msg.sender == master, "Not master!");
        for (uint256 i = 0; i < _shares.length; i++) {
            Share calldata share = _shares[i];
            require(!shareRevealed[share.id], "Share already revealed!");
            shares[share.id] = share;
            shareRevealed[share.id] = true;
        }
        locked = true;
    }

    /**
     * @notice Reveals a new share. Requires a valid signature from the master.
     * @param _share      Full Share struct (may include dynamic array).
     * @param _signature  Master signature for this Share.
     */
    function revealWithSignature(Share calldata _share, bytes calldata _signature) external {
        require(msg.sender == _share.owner, "Only the share owner can reveal!");
        require(!locked, "Locked!");
        require(!shareRevealed[_share.id], "Share already revealed!");

        bytes memory abiShare = abi.encode(_share);

        bytes32 messageHash = keccak256(abiShare).toEthSignedMessageHash();
        address signer = messageHash.recover(_signature);
        require(signer == master, "Not signed by master!");

        shares[_share.id] = _share;
        shareRevealed[_share.id] = true;
    }

    /**
     * @notice Claims any unclaimed portion of a share’s emission.
     * @param _shareId Share identifier.
     */
    function trigger(uint256 _shareId) external nonReentrant {
        require(shareRevealed[_shareId], "Share not revealed!");

        (address owner, uint256 claimable, uint256 total) = calculateClaimable(_shareId);

        if (claimable > total) {
            claimable = total;
            emit ClaimableMoreThanTotal(_shareId); // Report malfunction
        }

        require(claimable > shareClaimed[_shareId], "Nothing to claim!");

        uint256 amount = claimable - shareClaimed[_shareId];
        shareClaimed[_shareId] += amount;
        require(shareClaimed[_shareId] <= total, "Can't claim more than total!");

        token.safeTransfer(owner, amount);
    }
}
