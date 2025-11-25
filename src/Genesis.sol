// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Genesis is ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    /// @notice Address authorized to sign valid Share objects.
    address public master;

    /// @notice 1:1 wrapper-token which can be redeemed with actual token
    IERC20 public wrapperToken;

    /// @notice ERC20 token distributed by this contract.
    IERC20 public token;

    struct SharpEmission {
        uint256 startTime; // Timestamp when this one-time emission becomes claimable
        uint256 amount; // Fixed amount that becomes instantly claimable at startTime
    }

    struct LinearEmission {
        uint256 startTime; // Timestamp when linear emission starts accruing
        uint256 amountPerSecond; // Number of tokens emitted per second after startTime
        uint256 cap; // Maximum amount that can ever be emitted linearly (hard cap)
    }

    struct Share {
        uint256 id; // Unique identifier for the share
        address owner; // Address that can claim this share's emissions

        SharpEmission[] sharpEmissions; // List of discrete time-based emissions that unlock instantly when reached
        LinearEmission linearEmission; // Emission that unlocks gradually over time at a fixed rate

        uint256 totalCap; // Maximum total amount that can ever be claimed (sharp + linear combined)
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

    constructor(address _master, IERC20 _token, IERC20 _wrapperToken) {
        master = _master;
        token = _token;
        wrapperToken = _wrapperToken;
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
        uint256 claimable = 0;

        for (uint256 i = 0; i < share.sharpEmissions.length; i++) {
            SharpEmission storage sharpEmission = share.sharpEmissions[i];
            if (block.timestamp >= sharpEmission.startTime) {
                claimable += sharpEmission.amount;
            }
        }

        if (block.timestamp > share.linearEmission.startTime) {
            uint256 linearPart =
                share.linearEmission.amountPerSecond * (block.timestamp - share.linearEmission.startTime);
            if (linearPart > share.linearEmission.cap) {
                linearPart = share.linearEmission.cap;
            }
            claimable += linearPart;
        }

        return (share.owner, claimable, share.totalCap);
    }

    /**
     * @notice Reveals a new share. Requires a valid signature from the master.
     * @param _share      Full Share struct (may include dynamic array).
     * @param _signature  Master signature for this Share.
     */
    function reveal(Share calldata _share, bytes calldata _signature) external {
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

    /**
     * @notice Redeem `wrapperToken` for the underlying `token` at 1:1 ratio.
     * @param amount Amount of wrapperToken to redeem.
     */
    function redeem(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");

        // Transfer wrapperToken from user to contract
        wrapperToken.safeTransferFrom(msg.sender, address(this), amount);

        // Transfer underlying token to user
        token.safeTransfer(msg.sender, amount);
    }
}
