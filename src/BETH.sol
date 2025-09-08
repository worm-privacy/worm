// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ProofOfBurnVerifier} from "./ProofOfBurnVerifier.sol";
import {SpendVerifier} from "./SpendVerifier.sol";

contract BETH is ERC20 {
    uint256 public constant MINT_CAP = 1 ether;

    ProofOfBurnVerifier proofOfBurnVerifier;
    SpendVerifier spendVerifier;
    mapping(uint256 => bool) nullifiers;
    mapping(uint256 => uint256) coins; // Map each coin to its root coin
    mapping(uint256 => uint256) revealed; // Total revealed amount of a root coin

    constructor() ERC20("Burnt ETH", "BETH") {
        proofOfBurnVerifier = new ProofOfBurnVerifier();
        spendVerifier = new SpendVerifier();
    }

    function mintCoin(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256 _blockNumber,
        uint256 _nullifier,
        uint256 _remainingCoin,
        uint256 _fee,
        uint256 _spend,
        address _receiver
    ) public {
        require(_fee + _spend <= MINT_CAP); // Mint cap
        require(!nullifiers[_nullifier]);
        require(coins[_remainingCoin] == 0);
        bytes32 blockRoot = blockhash(_blockNumber);
        uint256 commitment = uint256(
            keccak256(
                abi.encodePacked(blockRoot, _nullifier, _remainingCoin, _fee, _spend, uint256(uint160(_receiver)))
            )
        ) >> 8;
        require(proofOfBurnVerifier.verifyProof(_pA, _pB, _pC, [commitment]), "Invalid proof!");
        _mint(msg.sender, _fee);
        _mint(_receiver, _spend);
        nullifiers[_nullifier] = true;
        coins[_remainingCoin] = _remainingCoin; // Minted coin is a root coin
        revealed[_remainingCoin] = _fee + _spend;
    }

    function spendCoin(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256 _coin,
        uint256 _amount,
        uint256 _remainingCoin,
        uint256 _fee,
        address _receiver
    ) public {
        uint256 rootCoin = coins[_coin];
        require(rootCoin != 0, "Coin does not exist");
        require(coins[_remainingCoin] == 0, "Remaining coin already exists");
        uint256 commitment =
            uint256(keccak256(abi.encodePacked(_coin, _amount, _remainingCoin, _fee, uint256(uint160(_receiver))))) >> 8;
        require(spendVerifier.verifyProof(_pA, _pB, _pC, [commitment]), "Invalid proof!");
        _mint(msg.sender, _fee);
        _mint(_receiver, _amount);
        coins[_coin] = 0;
        coins[_remainingCoin] = rootCoin;
        revealed[rootCoin] += _amount + _fee;
        require(revealed[rootCoin] <= MINT_CAP);
    }
}
