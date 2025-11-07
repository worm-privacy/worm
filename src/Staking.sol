// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking {
    using SafeERC20 for IERC20;

    struct StakeInfo {
        address owner;
        uint256 amount;
        uint256 startingEpoch;
        uint256 releaseEpoch;
    }

    uint256 constant EPOCH_TIME = 7 days;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public startingTime;

    mapping(uint256 => uint256) epochRewards;

    mapping(uint256 => uint256) totalStakings;
    mapping(uint256 => mapping(address => uint256)) userStakings;

    StakeInfo[] public stakeInfos;

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        startingTime = block.timestamp;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startingTime) / EPOCH_TIME;
    }

    function depositReward(uint256 _amount) external {
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        epochRewards[currentEpoch()] += _amount;
    }

    function lock(uint256 _amount, uint256 _numEpochs) external {
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
                releaseEpoch: startingEpoch + _numEpochs
            })
        );
    }

    function release(uint256 _stakeId) external {
        StakeInfo storage inf = stakeInfos[_stakeId];
        require(inf.amount != 0, "StakeInfo unavailable");
        require(currentEpoch() >= inf.releaseEpoch || currentEpoch() < inf.startingEpoch, "Stake is locked!");
        stakingToken.safeTransfer(inf.owner, inf.amount);
        inf.amount = 0;
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
