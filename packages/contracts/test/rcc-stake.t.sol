// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Test, console2} from "forge-std/Test.sol";
import {RCCStake} from "../contracts/rcc-stake.sol";
import {RCC} from "../contracts/rcc.sol";

contract RCCStakeTest is Test {
    RCCStake RCCStake;
    RCC RCC;

    fallback() external payable {}

    receive() external payable {}

    function setUp() public {
        RCC = new RCC(); // 所以new的结果是返回合约地址么？
        RCCStake = new RCCStake();
        RCCStake.initialize(RCC, 100, 100000000, 3000000000000000000);
    }

    function test_AddPool() public {
        // 创建eth质押池
        address _stakeTokenAddress = address(0x0);
        uint256 _poolWeight = 100;
        uint256 _minDepositAmount = 100;
        uint256 _withdrawLockedBlocks = 100;
        bool _withUpdate = true;

        RCCStake.addPool(
            _stakeTokenAddress,
            _poolWeight,
            _minDepositAmount,
            _withdrawLockedBlocks,
            _withUpdate
        );
        (
            address stakeTokenAddress,
            uint256 poolWeight,
            uint256 lastRewardBlock,
            uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            uint256 stakeTokenAmount /**质押的总代币数量 */,
            uint256 minDepositAmount /** 最小质押金额 */,
            uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStake.pool(0);

        assertEq(stakeTokenAddress, _stakeTokenAddress);
        assertEq(poolWeight, _poolWeight);
        assertEq(minDepositAmount, _minDepositAmount);
        assertEq(_withdrawLockedBlocks, unStakeLockedBlocks);
        assertEq(stakeTokenAmount, 0);
        assertEq(lastRewardBlock, 100);
        assertEq(accumulateRewardsPerStake, 0);
    }

    function test_massUpdatePools() public {
        test_AddPool();
        RCCStake.massUpdatePools();
        (
            address stakeTokenAddress,
            uint256 poolWeight,
            uint256 lastRewardBlock,
            uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            uint256 stakeTokenAmount /**质押的总代币数量 */,
            uint256 minDepositAmount /** 最小质押金额 */,
            uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStake.pool(0);
        assertEq(minDepositAmount, 100);
        assertEq(unStakeLockedBlocks, 100);
        assertEq(lastRewardBlock, 100);
        // Set block.height (newHeight)
        vm.roll(1000);
        RCCStake.massUpdatePools();
        (
            stakeTokenAddress,
            poolWeight,
            lastRewardBlock,
            accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            stakeTokenAmount /**质押的总代币数量 */,
            minDepositAmount /** 最小质押金额 */,
            unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStake.pool(0);
        assertEq(minDepositAmount, 100);
        assertEq(unStakeLockedBlocks, 100);
        assertEq(lastRewardBlock, 100);
    }

    function test_SetPoolWeight() public {
        test_AddPool();
        uint256 preTotalPoolWeight = RCCStake.totalPoolWeight();
        RCCStake.setPoolWeight(0, 200, false);
        (, uint256 poolWeight) = RCCStake.pool(0);
        uint256 totalPoolWeight = RCCStake.totalPoolWeight();
        uint256 expectedTotalPoolWeight = preTotalPoolWeight - 100 + 200;
        assertEq(poolWeight, 200);
        assertEq(totalPoolWeight, expectedTotalPoolWeight);
    }

    function test_DepositNativeCurrency() public {
        test_AddPool();
        (
            address stakeTokenAddress,
            uint256 poolWeight,
            uint256 lastRewardBlock,
            uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            uint256 stakeTokenAmount /**质押的总代币数量 */,
            uint256 minDepositAmount /** 最小质押金额 */,
            uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStake.pool(0);
        uint256 prePoolStakeTokenAmount = stakeTokenAmount;
        (
            uint stakeAmount,
            uint256 finishedRewards,
            uint256 pendingRewards
        ) = RCCStake.users(
                0,
                address(this)
            ); /** TODO: 这个语法没看懂，加个address this是干啥的？A:通过使用 address(this)，测试合约可以模拟一个真实用户的行为，查询自己（作为用户）的质押信息 */
        uint256 preStakeAmount = stakeAmount;
        uint256 preFinishedRewards = finishedRewards;
        uint256 prePendingRewards = pendingRewards;
        // 第一次质押
        address(RCCStake).call{value: 100}(
            abi.encodeWithSignature("depositNativeCurrency(address,uint256)")
        );
        (
            stakeTokenAddress,
            poolWeight,
            lastRewardBlock,
            accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            stakeTokenAmount /**质押的总代币数量 */,
            minDepositAmount /** 最小质押金额 */,
            unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStake.pool(0);

        (stakeAmount, finishedRewards, pendingRewards) = RCCStake.users(
            0,
            address(this)
        );
        uint256 expectedStAmount = preStakeAmount + 100;
        uint256 expectedFinishedRCC = preFinishedRewards;
        uint256 expectedTotalStTokenAmount = prePoolStakeTokenAmount + 100;

        assertEq(stakeAmount, expectedStAmount);
        assertEq(finishedRewards, expectedFinishedRCC);
        assertEq(stakeTokenAmount, expectedTotalStTokenAmount);

        // 多存几次
        address(RCCStake).call{value: 200}(
            abi.encodeWithSignature("depositNativeCurrency(address,uint256)")
        );

        vm.roll(2000000);
        RCCStake.unstake(0, 100);
        address(RCCStake).call{value: 300}(
            abi.encodeWithSignature("depositNativeCurrency(address,uint256)")
        );
        vm.roll(3000000);
        RCCStake.unstake(0, 100);
        address(RCCStake).call{value: 400 ether}(
            abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(4000000);
        RCCStake.unstake(0, 100);
        address(RCCStake).call{value: 500 ether}(
            abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(5000000);
        RCCStake.unstake(0, 100);
        address(RCCStake).call{value: 600 ether}(
            abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(6000000);
        RCCStake.unstake(0, 100);
        address(RCCStake).call{value: 700 ether}(
            abi.encodeWithSignature("depositnativeCurrency()")
        );

        RCCStake.withdraw(0);

        // TODO: 这里不该有一些对于数据的eq校验么？A：这些应该是给后续的测试准备用的；
    }

    function test_Unstake() public {
        test_DepositNativeCurrency();
        vm.roll(1000);
        RCCStake.unstake(0, 100);

        (
            uint256 stakeAmount,
            uint256 finishedRewards,
            uint256 pendingRewards
        ) = RCCStake.user(0, address(this));
        assertEq(stakeAmount, 0);
        assertEq(finishedRewards, 0);
        assertGt(pendingRewards, 0);

        (
            address stakeTokenAddress,
            uint256 poolWeight,
            uint256 lastRewardBlock,
            uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            uint256 stakeTokenAmount /**质押的总代币数量 */,
            uint256 minDepositAmount /** 最小质押金额 */,
            uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStake.pool(0);

        uint256 expectedStakeTokenAmount = 0;
        assertEq(stakeTokenAmount, expectedStakeTokenAmount);
    }

    function test_Withdraw() public {
        test_Unstake();
        // FIXME: 语法还没弄懂
        uint256 preContractBalance = address(RCCStake).balance;
        uint256 preUserBalance = address(this).balance;

        vm.roll(10000);
        RCCStake.withdraw(0);

        uint256 postContractBalance = address(RCCStake).balance;
        uint256 postUserBalance = address(this).balance;
        // Asserts left is strictly less than right.
        assertLt(postContractBalance, preContractBalance);
        // Asserts left is strictly greater than right.
        assertGt(postUserBalance, preUserBalance);
    }

    function test_claimAfterDeposit() public {
        test_DepositNativeCurrency();
        RCC.transfer(address(RCCStake), 100000000000);
        uint256 preUserRCCBalance = RCC.balanceOf(address(this));

        vm.roll(10000);
        RCCStake.claim(0);

        uint256 postUserRCCBalance = RCC.balanceOf(address(this));
        assertGt(postUserRCCBalance, preUserRCCBalance);
    }

    function addPool(uint256 index, address stakeTokenAddress) public {
        address _stakeTokenAddress = stakeTokenAddress;
        uint256 _poolWeight = 100;
        uint256 _minDepositAmount = 100;
        uint256 _withdrawLockedBlocks = 100;
        bool _update = true;
        RCCStake.addPool(
            index,
            _stakeTokenAddress,
            _poolWeight,
            _minDepositAmount,
            _withdrawLockedBlocks,
            _update
        );
    }
}
