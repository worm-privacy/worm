// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WORM is ERC20, ERC20Permit {
    event EpochContribution(uint256 indexed epoch, address participant, uint256 amount);
    event Participated(address indexed participant, uint256 fromEpoch, uint256 numEpochs, uint256 amountPerEpoch);
    event Claimed(address indexed claimant, uint256 fromEpoch, uint256 numEpochs, uint256 totalClaimed);

    uint256 constant EPOCH_DURATION = 600 seconds;
    uint256 constant INITIAL_REWARD_PER_EPOCH = 50 ether;
    uint256 constant REWARD_DECAY_NUMERATOR = 9999966993045875;
    uint256 constant REWARD_DECAY_DENOMINATOR = 10000000000000000;
    uint256 constant DEFAULT_INFO_MARGIN = 5; // X epochs before and X epochs after the current epoch

    IERC20 public immutable bethContract;
    uint256 public immutable startingTimestamp;

    uint256 public cachedRewardEpoch = 0;
    mapping(uint256 => uint256) public cachedReward;
    uint256 public cachedRewardsAccumulatedSum = 0;

    mapping(uint256 => uint256) public epochTotal;
    mapping(uint256 => mapping(address => uint256)) public epochUser;
    mapping(uint256 => uint256) public epochCount;

    /**
     * @notice Deploys the WORM contract with initial configuration.
     * @dev Sets the beth contract address, initializes the starting timestamp, caches the initial reward, and mints a premine.
     * @param _bethContract The address of the BETH token contract.
     * @param _premineAddress The address to receive the initial premine.
     * @param _premineAmount The amount of WORM tokens to premine.
     */
    constructor(IERC20 _bethContract, address _premineAddress, uint256 _premineAmount, uint256 _startingTimestamp)
        ERC20("WORM", "WORM")
        ERC20Permit("WORM")
    {
        bethContract = _bethContract;
        startingTimestamp = _startingTimestamp != 0 ? _startingTimestamp : block.timestamp;
        cachedReward[0] = INITIAL_REWARD_PER_EPOCH;
        cachedRewardsAccumulatedSum = INITIAL_REWARD_PER_EPOCH;
        if (_premineAddress != address(0)) {
            _mint(_premineAddress, _premineAmount);
        }
    }

    /**
     * @notice Returns the current epoch number based on the starting block and blocks per epoch.
     * @dev The epoch number is calculated by dividing the number of blocks since the starting block by the number of blocks per epoch.
     * @return The current epoch number.
     */
    function currentEpoch() public view returns (uint256) {
        require(block.timestamp >= startingTimestamp, "Mining has not started yet!");
        return (block.timestamp - startingTimestamp) / EPOCH_DURATION;
    }

    /**
     * @notice Computes reward of an specific epoch.
     * @dev It will used the cached reward to speed things up.
     * @param epoch The epoch to calculate reward for.
     */
    function rewardOf(uint256 epoch) public view returns (uint256) {
        if (epoch <= cachedRewardEpoch) {
            return cachedReward[epoch];
        }
        uint256 currRewardEpoch = cachedRewardEpoch;
        uint256 reward = cachedReward[currRewardEpoch];
        while (currRewardEpoch < epoch) {
            reward = (reward * REWARD_DECAY_NUMERATOR) / REWARD_DECAY_DENOMINATOR;
            currRewardEpoch += 1;
        }
        return reward;
    }

    /**
     * @notice Returns the current reward amount for the current epoch.
     * @dev This function calls `rewardOf(currentEpoch())` to get the current epoch’s reward value.
     * @return The current epoch reward amount.
     */
    function currentReward() public view returns (uint256) {
        return rewardOf(currentEpoch());
    }

    /**
     * @notice Allows a user to get the claim amount of their rewards for participation in past epochs.
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     * @param _startingEpoch The starting epoch number from which to claim rewards.
     * @param _numEpochs The number of epochs to claim rewards for.
     * @param _user The user address.
     */
    function calculateMintAmount(uint256 _startingEpoch, uint256 _numEpochs, address _user)
        public
        view
        returns (uint256)
    {
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
     * @notice Estimates the amount of tokens that can be minted for a given participation over multiple epochs.
     * @dev This function calculates the approximate mint amount based on the user's participation and the total participation in each epoch.
     * @param _amountPerEpoch The amount the user plans to participateco per epoch.
     * @param _numEpochs The number of epochs the user plans to participate in.
     * @return The approximate amount of tokens that can be minted.
     */
    function approximate(uint256 _amountPerEpoch, uint256 _numEpochs) public view returns (uint256) {
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

    function epochsWithNonZeroRewards(uint256 _fromEpoch, uint256 _numEpochs, address _user, uint256 _maxFound)
        public
        view
        returns (uint256 nextEpochToSearch, uint256[] memory epochs)
    {
        // Initialize epochs array with maxFound capacity
        epochs = new uint256[](_maxFound);
        uint256 foundCount = 0;

        uint256 maxEpoch = _fromEpoch + _numEpochs;
        uint256 i = _fromEpoch;
        while (i < maxEpoch) {
            // Check if user has claimable reward
            if (epochUser[i][_user] > 0) {
                epochs[foundCount] = i;
                foundCount++;
                if (foundCount >= _maxFound) {
                    i++;
                    break;
                }
            }
            i++;
        }

        // Resize the array to actual found count
        assembly {
            mstore(epochs, foundCount)
        }

        nextEpochToSearch = i;
    }

    struct Info {
        uint256 totalWorm;
        uint256 totalBeth;
        uint256 currentEpoch;
        uint256 currentEpochReward;
        uint256 epochRemainingTime;
        uint256 since;
        uint256[] userContribs;
        uint256[] totalContribs;
        uint256[] countContribs;
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
        if (since == 0 && count == 0) {
            uint256 epoch = currentEpoch();
            since = epoch >= DEFAULT_INFO_MARGIN ? (epoch - DEFAULT_INFO_MARGIN) : 0;
            count = 1 + 2 * DEFAULT_INFO_MARGIN;
        }
        uint256 totalBeth = bethContract.totalSupply();
        uint256 totalWorm = this.totalSupply();
        uint256 epochRemainingTime =
            EPOCH_DURATION - (block.timestamp - startingTimestamp - currentEpoch() * EPOCH_DURATION);
        uint256[] memory userContribs = new uint256[](count);
        uint256[] memory totalContribs = new uint256[](count);
        uint256[] memory countContribs = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            userContribs[i] = epochUser[i + since][user];
            totalContribs[i] = epochTotal[i + since];
            countContribs[i] = epochCount[i + since];
        }
        return Info({
            totalWorm: totalWorm,
            totalBeth: totalBeth,
            currentEpoch: currentEpoch(),
            currentEpochReward: currentReward(),
            since: since,
            epochRemainingTime: epochRemainingTime,
            userContribs: userContribs,
            totalContribs: totalContribs,
            countContribs: countContribs
        });
    }

    struct EpochRange {
        uint256 startingEpoch;
        uint256 numEpochs;
    }

    /**
     * @notice Estimates the amount of tokens that can be minted for an array of epoch ranges.
     * @dev Ensures the ranges do not overlap with each other!
     * @param _epochRanges Array of epoch ranges
     * @return The approximate amount of tokens that can be minted.
     */
    function multiApproximate(EpochRange[] calldata _epochRanges) public view returns (uint256) {
        uint256 mintAmount = 0;
        for (uint256 i = 0; i < _epochRanges.length; i++) {
            if (i > 0) {
                require(
                    _epochRanges[i].startingEpoch >= _epochRanges[i - 1].startingEpoch + _epochRanges[i - 1].numEpochs,
                    "Ranges overlap!"
                );
            }
            mintAmount += approximate(_epochRanges[i].startingEpoch, _epochRanges[i].numEpochs);
        }
        return mintAmount;
    }

    /*
     * ========================
     * END OF VIEW FUNCTION!
     * =======================
     */

    /**
     * @notice Computes and caches rewards up to an epoch.
     * @dev If the reward for the epoch has not been cached, it iteratively calculates it based on the decay rate until the requested epoch.
     * @param epoch The last epoch to calculate reward for.
     */
    function cacheRewards(uint256 epoch) public {
        uint256 currRewardEpoch = cachedRewardEpoch;
        uint256 reward = cachedReward[currRewardEpoch];
        uint256 rewardSum = 0;
        while (currRewardEpoch < epoch) {
            reward = (reward * REWARD_DECAY_NUMERATOR) / REWARD_DECAY_DENOMINATOR;
            currRewardEpoch += 1;
            cachedReward[currRewardEpoch] = reward;
            rewardSum += reward;
        }
        cachedRewardEpoch = currRewardEpoch;
        cachedRewardsAccumulatedSum += rewardSum;
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
            epochCount[currEpoch + i] += 1;
            emit EpochContribution(currEpoch + i, msg.sender, _amountPerEpoch);
        }
        require(bethContract.transferFrom(msg.sender, address(this), _numEpochs * _amountPerEpoch), "TF");
        emit Participated(msg.sender, currEpoch, _numEpochs, _amountPerEpoch);
    }

    /**
     * @notice Allows a user to claim their rewards for participation in past epochs.
     * @dev This function calculates and mints the reward based on the user's participation and the total participation in each epoch.
     * @param _startingEpoch The starting epoch number from which to claim rewards.
     * @param _numEpochs The number of epochs to claim rewards for.
     */
    function claim(uint256 _startingEpoch, uint256 _numEpochs) public {
        cacheRewards(_startingEpoch + _numEpochs);
        uint256 mintAmount = calculateMintAmount(_startingEpoch, _numEpochs, msg.sender);
        _mint(msg.sender, mintAmount);
        for (uint256 i = 0; i < _numEpochs; i++) {
            epochUser[_startingEpoch + i][msg.sender] = 0;
        }
        emit Claimed(msg.sender, _startingEpoch, _numEpochs, mintAmount);
    }

    /**
     * @notice Allows a user to claim multiple epoch ranges.
     * @param _epochRanges Array of epoch ranges
     */
    function multiClaim(EpochRange[] calldata _epochRanges) external {
        for (uint256 i = 0; i < _epochRanges.length; i++) {
            claim(_epochRanges[i].startingEpoch, _epochRanges[i].numEpochs);
        }
    }
}
