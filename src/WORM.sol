// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WORM is ERC20 {
    uint256 constant BLOCK_PER_EPOCH = 10;
    uint256 constant REWARD_PER_EPOCH = 50 ether;

    IERC20 public bethContract;
    uint256 public startingTimestamp;

    mapping(uint256 => uint256) public epochTotal;
    mapping(uint256 => mapping(address => uint256)) public epochUser;

    constructor(IERC20 _bethContract) ERC20("WORM", "WORM") {
        bethContract = _bethContract;
        startingTimestamp = block.timestamp;
    }

    /**
     * @notice Returns the current epoch number based on the starting block and blocks per epoch.
     *
     * @dev The epoch number is calculated by dividing the number of blocks since the starting block by the number of blocks per epoch.
     *
     * @return The current epoch number.
     */
    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startingTimestamp) / 1800 seconds;
    }

    /**
     * @notice Estimates the amount of tokens that can be minted for a given participation over multiple epochs.
     *
     * @dev This function calculates the approximate mint amount based on the user's participation and the total participation in each epoch.
     *
     * @param _amountPerEpoch The amount the user plans to participate per epoch.
     * @param _numEpochs The number of epochs the user plans to participate in.
     * @return The approximate amount of tokens that can be minted.
     */
    function approximate(
        uint256 _amountPerEpoch,
        uint256 _numEpochs
    ) public view returns (uint256) {
        uint256 mint_amount = 0;
        uint256 currEpoch = currentEpoch();
        for (uint256 i = 0; i < _numEpochs; i++) {
            uint256 epochIndex = currEpoch + i;
            uint256 user = epochUser[epochIndex][msg.sender] +
                _amountPerEpoch;
            uint256 total = epochTotal[epochIndex] + _amountPerEpoch;
            mint_amount += (REWARD_PER_EPOCH * user) / total;
        }
        return mint_amount;
    }

    /**
     * @notice Allows a user to participate in the reward program by locking tokens for multiple epochs.
     *
     * @dev This function updates the user's participation in the specified number of epochs and transfers the required amount of beth tokens to the contract.
     *
     * @param _amountPerEpoch The amount of tokens to lock per epoch.
     * @param _numEpochs The number of epochs to participate in.
     */
    function participate(
        uint256 _amountPerEpoch,
        uint256 _numEpochs
    ) external {
        require(_numEpochs != 0, "Invalid epoch number.");
        uint256 currEpoch = currentEpoch();
        for (uint256 i = 0; i < _numEpochs; i++) {
            epochTotal[currEpoch + i] += _amountPerEpoch;
            epochUser[currEpoch + i][msg.sender] += _amountPerEpoch;
        }
        require(
            bethContract.transferFrom(
                msg.sender,
                address(this),
                _numEpochs * _amountPerEpoch
            ),
            "TF"
        );
    }

    /**
     * @notice Allows a user to get the claim amount of their rewards for participation in past epochs.
     *
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     *
     * @param _startingEpoch The starting epoch number from which to claim rewards.
     * @param _numEpochs The number of epochs to claim rewards for.
     * @param _user The user address.
     */
    function calculateMintAmount(
        uint256 _startingEpoch,
        uint256 _numEpochs,
        address _user
    ) public view returns (uint256) {
        require(
            _startingEpoch + _numEpochs <= currentEpoch(),
            "Cannot claim an ongoing epoch!"
        );
        uint256 mintAmount = 0;
        for (uint256 i = 0; i < _numEpochs; i++) {
            uint256 total = epochTotal[_startingEpoch + i];
            if (total > 0) {
                uint256 user = epochUser[_startingEpoch + i][_user];
                mintAmount += (REWARD_PER_EPOCH * user) / total;
            }
        }
        return mintAmount;
    }

    /**
     * @notice Allows a user to claim their rewards for participation in past epochs.
     *
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     *
     * @param _startingEpoch The starting epoch number from which to claim rewards.
     * @param _numEpochs The number of epochs to claim rewards for.
     */
    function claim(
        uint256 _startingEpoch,
        uint256 _numEpochs
    ) external returns (uint256) {
        uint256 mintAmount = calculateMintAmount(
            _startingEpoch,
            _numEpochs,
            msg.sender
        );
        _mint(msg.sender, mintAmount);
        for (uint256 i = 0; i < _numEpochs; i++) {
            epochUser[_startingEpoch + i][msg.sender] = 0;
        }
        return mintAmount;
    }
}
