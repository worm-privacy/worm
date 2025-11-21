// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRewardPool {
    function depositReward(uint256 _amount) external;
}

contract Staking is IRewardPool {
    event RewardDeposited(address indexed depositor, uint256 epoch, uint256 amount);
    event Staked(address indexed user, uint256 indexed stakeId, uint256 amount, uint256 startingEpoch, uint256 releaseEpoch, uint256 numEpochs);
    event Released(address indexed user, uint256 indexed stakeId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 fromEpoch, uint256 count, uint256 totalReward);

    using SafeERC20 for IERC20;

    uint256 constant EPOCH_DURATION = 7 days;
    uint256 constant DEFAULT_INFO_MARGIN = 5; // X epochs before and X epochs after the current epoch

    struct StakeInfo {
        address owner;
        uint256 amount;
        uint256 startingEpoch;
        uint256 releaseEpoch;
        bool released;
    }

    IERC20 public stakingToken;
    IERC20 public rewardToken;
    uint256 public startingTimestamp;
    mapping(uint256 => uint256) public epochReward;
    mapping(uint256 => uint256) public epochTotalLocked;
    mapping(uint256 => mapping(address => uint256)) public epochUserLocked;

    StakeInfo[] public stakeInfos;

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        startingTimestamp = block.timestamp;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startingTimestamp) / EPOCH_DURATION;
    }

    struct Info {
        uint256 currentEpoch;
        uint256 epochRemainingTime;
        uint256 since;
        uint256[] userLocks;
        uint256[] totalLocks;
        uint256[] rewards;
    }

    /**
     * @notice Returns general contract statistics and lock details for a user.
     * @dev Provides current epoch info, remaining time in the current epoch, and user/total locks and rewards for a range of epochs.
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
        uint256 epochRemainingTime = block.timestamp - startingTimestamp - currentEpoch() * EPOCH_DURATION;
        uint256[] memory rewards = new uint256[](count);
        uint256[] memory userLocks = new uint256[](count);
        uint256[] memory totalLocks = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            userLocks[i] = epochUserLocked[i + since][user];
            totalLocks[i] = epochTotalLocked[i + since];
            rewards[i] = epochReward[i + since];
        }
        return Info({
            currentEpoch: currentEpoch(),
            since: since,
            epochRemainingTime: epochRemainingTime,
            userLocks: userLocks,
            totalLocks: totalLocks,
            rewards: rewards
        });
    }

    function depositReward(uint256 _amount) external {
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 epoch = currentEpoch();
        epochReward[epoch] += _amount;
        emit RewardDeposited(msg.sender, epoch, _amount);
    }

    function lock(uint256 _amount, uint256 _numEpochs) external {
        require(_amount > 0, "No amount specified!");
        uint256 startingEpoch = currentEpoch() + 1;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        for (uint256 i = startingEpoch; i < startingEpoch + _numEpochs; i++) {
            epochUserLocked[i][msg.sender] += _amount;
            epochTotalLocked[i] += _amount;
        }
        uint256 stakeId = stakeInfos.length;
        stakeInfos.push(
            StakeInfo({
                owner: msg.sender,
                amount: _amount,
                startingEpoch: startingEpoch,
                releaseEpoch: startingEpoch + _numEpochs,
                released: false
            })
        );
        emit Staked(msg.sender, stakeId, _amount, startingEpoch, startingEpoch + _numEpochs, _numEpochs);
    }

    function release(uint256 _stakeId) external {
        StakeInfo storage inf = stakeInfos[_stakeId];
        require(inf.amount != 0, "StakeInfo unavailable");
        require(!inf.released, "Already released!");
        require(currentEpoch() >= inf.releaseEpoch, "Stake is locked!");
        stakingToken.safeTransfer(inf.owner, inf.amount);
        inf.released = true;
        emit Released(inf.owner, _stakeId, inf.amount);
    }

    function claimReward(uint256 _fromEpoch, uint256 _count) external {
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
