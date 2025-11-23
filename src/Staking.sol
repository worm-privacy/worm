// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IRewardPool {
    function depositReward(uint256 _amount) external;
}

contract Staking is IRewardPool, ReentrancyGuard {
    event RewardDeposited(address indexed depositor, uint256 epoch, uint256 amount);
    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 startingEpoch,
        uint256 releaseEpoch,
        uint256 numEpochs
    );
    event Released(address indexed user, uint256 indexed stakeId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 fromEpoch, uint256 count, uint256 totalReward);

    using SafeERC20 for IERC20;

    uint256 constant EPOCH_DURATION = 7 days;
    uint256 constant DEFAULT_INFO_MARGIN = 5; // X epochs before and X epochs after the current epoch

    /// @notice Represents a user's locked stake.
    struct Stake {
        address owner; // Address that owns the stake
        uint256 amount; // Amount of tokens staked
        uint256 startingEpoch; // Epoch when staking becomes active
        uint256 releaseEpoch; // Epoch when tokens can be released
        bool released; // Whether the stake has already been released
    }

    IERC20 public stakingToken;
    IERC20 public rewardToken;
    uint256 public startingTimestamp;
    mapping(uint256 => uint256) public epochReward;
    mapping(uint256 => uint256) public epochTotalLocked;
    mapping(uint256 => mapping(address => uint256)) public epochUserLocked;

    Stake[] public stakes;

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        startingTimestamp = block.timestamp;
    }

    /// @notice Returns the current epoch index based on time since deployment.
    /// @return The zero-based epoch number.
    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startingTimestamp) / EPOCH_DURATION;
    }

    /// @notice Aggregated epoch, lock, and reward information returned by `info()`.
    struct EpochStats {
        uint256 currentEpoch; // Current epoch number
        uint256 epochRemainingTime; // Seconds left in the current epoch
        uint256 since; // Starting epoch index for data arrays
        uint256[] userLocks; // User's locked amounts per epoch
        uint256[] totalLocks; // Total locked amounts per epoch
        uint256[] rewards; // Reward amounts per epoch
    }

    /**
     * @notice Retrieves aggregated staking/reward info for a user for a range of epochs.
     * @dev If `since` and `count` are zero, a default window centered around current epoch is returned.
     * @param user The address whose stake and reward information is being queried.
     * @param since The first epoch index to include.
     * @param count The number of epochs to fetch.
     * @return An `Info` struct containing epoch stats.
     */
    function info(address user, uint256 since, uint256 count) public view returns (EpochStats memory) {
        if (since == 0 && count == 0) {
            uint256 epoch = currentEpoch();
            since = epoch >= DEFAULT_INFO_MARGIN ? (epoch - DEFAULT_INFO_MARGIN) : 0;
            count = 1 + 2 * DEFAULT_INFO_MARGIN;
        }
        uint256 epochRemainingTime = block.timestamp - startingTimestamp - currentEpoch() * EPOCH_DURATION;
        uint256[] memory rewards = new uint256[](count);
        uint256[] memory userLocks = new uint256[](count);
        uint256[] memory totalLocks = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            userLocks[i] = epochUserLocked[i + since][user];
            totalLocks[i] = epochTotalLocked[i + since];
            rewards[i] = epochReward[i + since];
        }
        return EpochStats({
            currentEpoch: currentEpoch(),
            since: since,
            epochRemainingTime: epochRemainingTime,
            userLocks: userLocks,
            totalLocks: totalLocks,
            rewards: rewards
        });
    }

    /// @notice Deposits reward tokens to be distributed for the current epoch.
    /// @dev The caller must approve the contract before calling.
    /// @param _amount Amount of reward tokens to deposit.
    function depositReward(uint256 _amount) external nonReentrant {
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 epoch = currentEpoch();
        epochReward[epoch] += _amount;
        emit RewardDeposited(msg.sender, epoch, _amount);
    }

    /**
     * @notice Locks staking tokens for a specified number of future epochs.
     * @dev Locking starts from the next epoch (currentEpoch + 1).
     * @param _amount The number of tokens to lock.
     * @param _numEpochs Number of epochs the tokens will remain locked.
     */
    function lock(uint256 _amount, uint256 _numEpochs) external nonReentrant {
        require(_amount > 0, "No amount specified!");
        uint256 startingEpoch = currentEpoch() + 1;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        for (uint256 i = startingEpoch; i < startingEpoch + _numEpochs; i++) {
            epochUserLocked[i][msg.sender] += _amount;
            epochTotalLocked[i] += _amount;
        }
        uint256 stakeId = stakes.length;
        stakes.push(
            Stake({
                owner: msg.sender,
                amount: _amount,
                startingEpoch: startingEpoch,
                releaseEpoch: startingEpoch + _numEpochs,
                released: false
            })
        );
        emit Staked(msg.sender, stakeId, _amount, startingEpoch, startingEpoch + _numEpochs, _numEpochs);
    }

    /**
     * @notice Releases a user's staked tokens after the lock period ends.
     * @param _stakeId The ID of the stake to release.
     */
    function release(uint256 _stakeId) external nonReentrant {
        Stake storage stake = stakes[_stakeId];
        require(stake.amount != 0, "StakeInfo unavailable");
        require(!stake.released, "Already released!");
        require(currentEpoch() >= stake.releaseEpoch, "Stake is locked!");
        stake.released = true;
        stakingToken.safeTransfer(stake.owner, stake.amount);
        emit Released(stake.owner, _stakeId, stake.amount);
    }

    /**
     * @notice Claims rewards from a range of epochs that have already completed.
     * @dev User’s share is proportional to their locked amount in each epoch.
     * @param _fromEpoch First epoch to claim rewards from.
     * @param _count Number of epochs to claim.
     */
    function claimReward(uint256 _fromEpoch, uint256 _count) external nonReentrant {
        require(currentEpoch() >= _fromEpoch + _count, "Cannot claim ongoing epoch!");
        uint256 totalReward = 0;
        for (uint256 i = _fromEpoch; i < _fromEpoch + _count; i++) {
            if (epochTotalLocked[i] > 0) {
                totalReward += epochReward[i] * epochUserLocked[i][msg.sender] / epochTotalLocked[i];
                epochUserLocked[i][msg.sender] = 0;
            }
        }
        rewardToken.safeTransfer(msg.sender, totalReward);
        emit RewardClaimed(msg.sender, _fromEpoch, _count, totalReward);
    }
}
