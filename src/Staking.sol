// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IRewardPool {
    function depositReward(uint256 _amount) external;
}

contract Staking is IRewardPool {
    uint256 constant DEFAULT_INFO_MARGIN = 5; // X epochs before and X epochs after the current epoch

    using SafeERC20 for IERC20;

    struct StakeInfo {
        address owner;
        uint256 amount;
        uint256 startingEpoch;
        uint256 releaseEpoch;
        bool released;
    }

    uint256 constant EPOCH_DURATION = 7 days;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public startingTime;

    mapping(uint256 => uint256) public epochRewards;

    mapping(uint256 => uint256) public totalStakings;
    mapping(uint256 => mapping(address => uint256)) public userStakings;

    StakeInfo[] public stakeInfos;

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        startingTime = block.timestamp;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startingTime) / EPOCH_DURATION;
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
        uint256 epochRemainingTime = block.timestamp - startingTime - currentEpoch() * EPOCH_DURATION;
        uint256[] memory rewards = new uint256[](count);
        uint256[] memory userLocks = new uint256[](count);
        uint256[] memory totalLocks = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            userLocks[i] = userStakings[i + since][user];
            totalLocks[i] = totalStakings[i + since];
            rewards[i] = epochRewards[i + since];
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
        epochRewards[currentEpoch()] += _amount;
    }

    function lock(uint256 _amount, uint256 _numEpochs) external {
        require(_amount > 0, "No amount specified!");
        uint256 startingEpoch = currentEpoch() + 1;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        for (uint256 i = startingEpoch; i < startingEpoch + _numEpochs; i++) {
            userStakings[i][msg.sender] += _amount;
            totalStakings[i] += _amount;
        }
        stakeInfos.push(
            StakeInfo({
                owner: msg.sender,
                amount: _amount,
                startingEpoch: startingEpoch,
                releaseEpoch: startingEpoch + _numEpochs,
                released: false
            })
        );
    }

    function release(uint256 _stakeId) external {
        StakeInfo storage inf = stakeInfos[_stakeId];
        require(inf.amount != 0, "StakeInfo unavailable");
        require(!inf.released, "Already released!");
        require(currentEpoch() >= inf.releaseEpoch, "Stake is locked!");
        stakingToken.safeTransfer(inf.owner, inf.amount);
        inf.released = true;
    }

    function claimReward(uint256 _fromEpoch, uint256 _count) external {
        require(currentEpoch() >= _fromEpoch + _count, "Cannot claim ongoing epoch!");
        uint256 totalReward = 0;
        for (uint256 i = _fromEpoch; i < _fromEpoch + _count; i++) {
            if (totalStakings[i] > 0) {
                totalReward += epochRewards[i] * userStakings[i][msg.sender] / totalStakings[i];
                userStakings[i][msg.sender] = 0;
            }
        }
        rewardToken.safeTransfer(msg.sender, totalReward);
    }
}
