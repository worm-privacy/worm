// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BETH is ERC20 {
    mapping(uint256 => bool) nullifiers;
    mapping(uint256 => bool) coins;

    constructor() ERC20("Burnt ETH", "BETH") {}

    function mintCoin(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256 _blockNumber,
        uint256 _nullifier,
        uint256 _encryptedBalance,
        uint256 _fee
    ) public {
        require(!nullifiers[_nullifier]);
        require(!coins[_encryptedBalance]);
        bytes32 blockRoot = blockhash(_blockNumber);
        uint256 commitment = uint256(keccak256(abi.encodePacked(blockRoot, _nullifier, _encryptedBalance)));
        commitment = commitment << 8 >> 8;
        _mint(msg.sender, _fee);
        nullifiers[_nullifier] = true;
        coins[_encryptedBalance] = true;
    }

    function spendCoin(uint256 _coin, uint256 _amount, uint256 _remainingCoin) public {
        require(coins[_coin]);
        require(!coins[_remainingCoin]);
        _mint(msg.sender, _amount);
        coins[_coin] = false;
        coins[_remainingCoin] = true;
    }
}
