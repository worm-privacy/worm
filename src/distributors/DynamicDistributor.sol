// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Distributor} from "./Distributor.sol";

contract DynamicDistributor is Distributor {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @notice Address authorized to sign valid Share objects.
    address public master;

    /// @notice Emitted when a share is successfully revealed.
    event ShareRevealed(Share share);

    constructor(IERC20 _token, uint256 _deadlineTimestamp, address _master) Distributor(_token, _deadlineTimestamp) {
        master = _master;
    }

    /**
     * @notice Reveals a new share. Requires a valid signature from the master.
     * @param _share      Full Share struct (may include dynamic array).
     * @param _signature  Master signature for this Share.
     */
    function reveal(Share calldata _share, bytes calldata _signature) external {
        require(block.timestamp < deadlineTimestamp, "Distribution has ended!");

        require(msg.sender == _share.owner, "Only the share owner can reveal!");
        require(_share.owner != address(0), "Share has no owner!");
        require(shares[_share.id].owner == address(0), "Share already revealed!");

        bytes memory abiShare = abi.encode(_share);

        bytes32 messageHash = keccak256(abiShare).toEthSignedMessageHash();
        address signer = messageHash.recover(_signature);
        require(signer == master, "Not signed by master!");

        shares[_share.id] = _share;
    }
}
