// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library RCCStakeLib {
    struct Pool {
        address stakeTokenAddress /** 质押池的代币地址 */;
        uint256 poolWeight /** 质押池的权重 */;
        uint256 lastRewardBlock /** 上次发放奖励的区块 */;
        uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币，每次发放后更新为0，未发放则持续累计 */;
        uint256 stakeTokenAmount /**质押的总代币数量 */;
        uint256 minDepositAmount /** 最小质押金额 */;
        uint256 unStakeLockedBlocks /** 禁止解除质押的区块 */;
    }
    struct UnStakeRequest {
        // Request withdraw amount
        uint256 amount;
        // The blocks when the request withdraw amount can be released，发起解除质押请求时，已解锁的区块数量
        uint256 unlockBlocksCounts;
    }
    struct User {
        uint256 stakeAmount;
        uint256 finishedRewards;
        uint256 pendingRewards;
        UnStakeRequest[] requests;
    }
}
