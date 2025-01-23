// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * 功能需求
 *
 * 质押池
 * - 质押池的创建
 * - 质押池的质押
 * - 质押池的赎回
 * - 质押池的奖励
 * - 质押池的奖励的发放
 */

struct Pool {
    address stTokenAddress /** 质押池的代币地址 */;
    uint256 poolWeight /** 质押池的权重 */;
    uint256 lastRewardBlock /** 上次奖励发放的区块高度 */;
    uint256 accRCCPerST /** 每个质押代币的累计 RCC 奖励 */;
    uint256 minDepositAmount /** 最小质押金额 */;
    uint256 unStakeLockedBlocks /** 解除质押的锁定区块数 */;
}

struct User {
    uint256 stAmount;
    uint256 finishedRCC;
    uint256 pendingRCC;
    uint256[] requests;
}

contract RCCStake is Initializable, UUPS {
    // ---------------- 状态变量 ----------------
    mapping(address => bool) private admins; /**管理员 */
    mapping(address => bool) private upgradeManagers; /**可升级角色 */

    // ---------------- 事件 ----------------

    event Stake(address indexed user, address indexed pid, uint256 amount);
    event UnStake(address indexed user, address indexed pid, uint256 amount);
    event GetRewards(address indexed user, address indexed pid, uint256 amount);

    // ---------------- 装饰器 ----------------
    modifier onlyAdmin() {
        require(admins[msg.sender], "only admin role can do this");
        _;
    }

    // ---------------- 函数 ----------------
    // 质押
    function stake(uint256 _pid, uint256 _amount) external {}

    // 解除质押
    function unStake(uint256 _pid, uint256 _amount) external {}

    // 领取奖励
    function getRewards() external {}

    // 添加、更新质押池
    function createPool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyAdmin {}

    function updatePool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyAdmin {}

    // 合约升级
    function upgradeContract() public {}

    // 合约暂停和开启
    function switchContractStatus() public {}
}
