// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WORM is ERC20 {
    uint256 constant EPOCH_DURATION = 600 seconds;
    uint256 constant INITIAL_REWARD_PER_EPOCH = 50 ether;
    uint256 constant REWARD_DECAY_NUMERATOR = 9999966993045875;
    uint256 constant REWARD_DECAY_DENOMINATOR = 10000000000000000;

    IERC20 public bethContract;
    uint256 public startingTimestamp;

    uint256 public cachedRewardEpoch = 0;
    mapping(uint256 => uint256) public cachedReward;

    mapping(uint256 => uint256) public epochTotal;
    mapping(uint256 => mapping(address => uint256)) public epochUser;

    /**
     * @notice Deploys the WORM contract with initial configuration.
     * @dev Sets the beth contract address, initializes the starting timestamp, caches the initial reward, and mints a premine.
     * @param _bethContract The address of the BETH token contract.
     * @param _premineAddress The address to receive the initial premine.
     * @param _premineAmount The amount of WORM tokens to premine.
     */
    constructor(IERC20 _bethContract, address _premineAddress, uint256 _premineAmount) ERC20("WORM", "WORM") {
        bethContract = _bethContract;
        startingTimestamp = block.timestamp;
        cachedReward[0] = INITIAL_REWARD_PER_EPOCH;
        _mint(_premineAddress, _premineAmount);
    }

    /**
     * @notice Returns the current epoch number based on the starting block and blocks per epoch.
     * @dev The epoch number is calculated by dividing the number of blocks since the starting block by the number of blocks per epoch.
     * @return The current epoch number.
     */
    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startingTimestamp) / EPOCH_DURATION;
    }

    /**
     * @notice Retrieves or computes the total reward for a specific epoch.
     * @dev If the reward for the epoch has not been cached, it iteratively calculates it based on the decay rate until the requested epoch.
     * @param epoch The epoch number for which to get the reward.
     * @return The reward amount for the specified epoch.
     */
    function rewardOf(uint256 epoch) public returns (uint256) {
        if (epoch <= cachedRewardEpoch) {
            return cachedReward[epoch];
        }
        uint256 reward = cachedReward[cachedRewardEpoch];
        while (cachedRewardEpoch < epoch) {
            reward = (reward * REWARD_DECAY_NUMERATOR) / REWARD_DECAY_DENOMINATOR;
            cachedRewardEpoch += 1;
            cachedReward[cachedRewardEpoch] = reward;
        }
        return reward;
    }

    /**
     * @notice Returns the current reward amount for the current epoch.
     * @dev This function calls `rewardOf(currentEpoch())` to get the current epoch’s reward value.
     * @return The current epoch reward amount.
     */
    function currentReward() public returns (uint256) {
        return rewardOf(currentEpoch());
    }

    /**
     * @notice Estimates the amount of tokens that can be minted for a given participation over multiple epochs.
     * @dev This function calculates the approximate mint amount based on the user's participation and the total participation in each epoch.
     * @param _amountPerEpoch The amount the user plans to participate per epoch.
     * @param _numEpochs The number of epochs the user plans to participate in.
     * @return The approximate amount of tokens that can be minted.
     */
    function approximate(uint256 _amountPerEpoch, uint256 _numEpochs) public returns (uint256) {
        uint256 mintAmount = 0;
        uint256 currEpoch = currentEpoch();
        for (uint256 i = 0; i < _numEpochs; i++) {
            uint256 epochIndex = currEpoch + i;
            uint256 reward = rewardOf(epochIndex);
            uint256 user = epochUser[epochIndex][msg.sender] + _amountPerEpoch;
            uint256 total = epochTotal[epochIndex] + _amountPerEpoch;
            mintAmount += (reward * user) / total;
        }
        return mintAmount;
    }

    /**
     * @notice Allows a user to participate in the reward program by locking tokens for multiple epochs.
     * @dev This function updates the user's participation in the specified number of epochs and transfers the required amount of beth tokens to the contract.
     * @param _amountPerEpoch The amount of tokens to lock per epoch.
     * @param _numEpochs The number of epochs to participate in.
     */
    function participate(uint256 _amountPerEpoch, uint256 _numEpochs) external {
        require(_numEpochs != 0, "Invalid epoch number.");
        uint256 currEpoch = currentEpoch();
        for (uint256 i = 0; i < _numEpochs; i++) {
            epochTotal[currEpoch + i] += _amountPerEpoch;
            epochUser[currEpoch + i][msg.sender] += _amountPerEpoch;
        }
        require(bethContract.transferFrom(msg.sender, address(this), _numEpochs * _amountPerEpoch), "TF");
    }

    /**
     * @notice Allows a user to get the claim amount of their rewards for participation in past epochs.
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     * @param _startingEpoch The starting epoch number from which to claim rewards.
     * @param _numEpochs The number of epochs to claim rewards for.
     * @param _user The user address.
     */
    function calculateMintAmount(uint256 _startingEpoch, uint256 _numEpochs, address _user) public returns (uint256) {
        require(_startingEpoch + _numEpochs <= currentEpoch(), "Cannot claim an ongoing epoch!");
        uint256 mintAmount = 0;
        for (uint256 i = 0; i < _numEpochs; i++) {
            uint256 total = epochTotal[_startingEpoch + i];
            if (total > 0) {
                uint256 user = epochUser[_startingEpoch + i][_user];
                mintAmount += (rewardOf(_startingEpoch + i) * user) / total;
            }
        }
        return mintAmount;
    }

    /**
     * @notice Allows a user to claim their rewards for participation in past epochs.
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     * @param _startingEpoch The starting epoch number from which to claim rewards.
     * @param _numEpochs The number of epochs to claim rewards for.
     */
    function claim(uint256 _startingEpoch, uint256 _numEpochs) external returns (uint256) {
        uint256 mintAmount = calculateMintAmount(_startingEpoch, _numEpochs, msg.sender);
        _mint(msg.sender, mintAmount);
        for (uint256 i = 0; i < _numEpochs; i++) {
            epochUser[_startingEpoch + i][msg.sender] = 0;
        }
        return mintAmount;
    }

    struct Info {
        uint256 totalWorm;
        uint256 totalBeth;
        uint256 currentEpoch;
        uint256 epochRemainingTime;
        uint256[] userContribs;
        uint256[] totalContribs;
    }

    /**
     * @notice Returns general contract statistics and participation details for a user.
     * @dev Provides total supplies, current epoch info, remaining time in the current epoch, and user/total contributions for a range of epochs.
     * @param user The address of the user to query.
     * @param since The starting epoch index for which to retrieve information.
     * @param count The number of epochs to include in the response.
     * @return An `Info` struct containing global and user-specific information.
     */
    function info(address user, uint256 since, uint256 count) public view returns (Info memory) {
        uint256 totalBeth = bethContract.totalSupply();
        uint256 totalWorm = this.totalSupply();
        uint256 epochRemainingTime = block.timestamp - startingTimestamp - currentEpoch() * EPOCH_DURATION;
        uint256[] memory userContribs = new uint256[](count);
        uint256[] memory totalContribs = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            userContribs[i] = epochUser[since + i][user];
            totalContribs[i] = epochTotal[since + i];
        }
        return Info({
            totalWorm: totalWorm,
            totalBeth: totalBeth,
            currentEpoch: currentEpoch(),
            epochRemainingTimegit: epochRemainingTime,
            userContribs: userContribs,
            totalContribs: totalContribs
        });
    }
}
