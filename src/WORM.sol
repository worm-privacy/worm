// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WORM is ERC20 {
    uint256 constant BLOCK_PER_EPOCH = 10;
    uint256 constant REWARD_PER_EPOCH = 50 ether;

    IERC20 public bethContract;
    uint256 public startingTimestamp;

    mapping(uint256 => uint256) public epochTotal;
    mapping(uint256 => mapping(address => uint256)) public epoch_user;

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
        return (block.timestamp - startingTimestamp) / 120 seconds;
    }

    /**
     * @notice Estimates the amount of tokens that can be minted for a given participation over multiple epochs.
     *
     * @dev This function calculates the approximate mint amount based on the user's participation and the total participation in each epoch.
     *
     * @param _amount_per_epoch The amount the user plans to participate per epoch.
     * @param _num_epochs The number of epochs the user plans to participate in.
     * @return The approximate amount of tokens that can be minted.
     */
    function approximate(uint256 _amount_per_epoch, uint256 _num_epochs) public view returns (uint256) {
        uint256 mint_amount = 0;
        uint256 currEpoch = currentEpoch();
        for (uint256 i = 0; i < _num_epochs; i++) {
            uint256 epochIndex = currEpoch + i;
            uint256 user = epoch_user[epochIndex][msg.sender] + _amount_per_epoch;
            uint256 total = epochTotal[epochIndex] + _amount_per_epoch;
            mint_amount += REWARD_PER_EPOCH * user / total;
        }
        return mint_amount;
    }

    /**
     * @notice Allows a user to participate in the reward program by locking tokens for multiple epochs.
     *
     * @dev This function updates the user's participation in the specified number of epochs and transfers the required amount of beth tokens to the contract.
     *
     * @param _amount_per_epoch The amount of tokens to lock per epoch.
     * @param _num_epochs The number of epochs to participate in.
     */
    function participate(uint256 _amount_per_epoch, uint256 _num_epochs) external {
        require(_num_epochs != 0, "Invalid epoch number.");
        uint256 currEpoch = currentEpoch();
        for (uint256 i = 0; i < _num_epochs; i++) {
            epochTotal[currEpoch + i] += _amount_per_epoch;
            epoch_user[currEpoch + i][msg.sender] += _amount_per_epoch;
        }
        require(bethContract.transferFrom(msg.sender, address(this), _num_epochs * _amount_per_epoch), "TF");
    }

    /**
     * @notice Allows a user to get the claim amount of their rewards for participation in past epochs.
     *
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     *
     * @param _starting_epoch The starting epoch number from which to claim rewards.
     * @param _num_epochs The number of epochs to claim rewards for.
     * @param _user The user address.
     */
    function calculateMintAmount(uint256 _starting_epoch, uint256 _num_epochs, address _user)
        public
        view
        returns (uint256)
    {
        require(_starting_epoch + _num_epochs <= currentEpoch(), "Cannot claim an ongoing epoch!");
        uint256 mint_amount = 0;
        for (uint256 i = 0; i < _num_epochs; i++) {
            uint256 total = epochTotal[_starting_epoch + i];
            if (total > 0) {
                uint256 user = epoch_user[_starting_epoch + i][_user];
                mint_amount += REWARD_PER_EPOCH * user / total;
            }
        }
        return mint_amount;
    }

    /**
     * @notice Allows a user to claim their rewards for participation in past epochs.
     *
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     *
     * @param _starting_epoch The starting epoch number from which to claim rewards.
     * @param _num_epochs The number of epochs to claim rewards for.
     */
    function claim(uint256 _starting_epoch, uint256 _num_epochs) external returns (uint256) {
        uint256 mint_amount = calculateMintAmount(_starting_epoch, _num_epochs, msg.sender);
        _mint(msg.sender, mint_amount);
        return mint_amount;
    }
}
