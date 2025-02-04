// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// TODO: 这个测试文件只能forge跑吧，hardhat能跑么？

import {Test, console2, Vm} from "forge-std/Test.sol";
import {RCCStake} from "../contracts/rcc-stake.sol";
import {RccToken} from "../contracts/rcc.sol";

contract RCCStakeTest is Test {
    RCCStake RCCStakeInstance;
    RccToken RCCInstance;

    fallback() external payable {}

    receive() external payable {}

    function setUp() public {
        RCCInstance = new RccToken(); // 所以new的结果是返回合约地址么？
        RCCStakeInstance = new RCCStake();
        RCCStakeInstance.initialize(
            RCCInstance,
            100,
            100000000,
            3000000000000000000 // 每个区块奖励多少代币
        );
        // 下面这行不需要了，一开始以为是ethers不够
        // vm.deal(address(this), 1000000);
    }

    function test_AddPool() public {
        // 创建eth质押池
        address _stakeTokenAddress = address(0x0);
        uint256 _poolWeight = 100;
        uint256 _minDepositAmount = 100;
        uint256 _withdrawLockedBlocks = 100;
        bool _withUpdate = true;

        RCCStakeInstance.addPool(
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
        ) = RCCStakeInstance.pool(0);

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
        RCCStakeInstance.massUpdatePools();
        (
            address stakeTokenAddress,
            uint256 poolWeight,
            uint256 lastRewardBlock,
            uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            uint256 stakeTokenAmount /**质押的总代币数量 */,
            uint256 minDepositAmount /** 最小质押金额 */,
            uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStakeInstance.pool(0);
        assertEq(minDepositAmount, 100);
        assertEq(unStakeLockedBlocks, 100);
        assertEq(lastRewardBlock, 100);
        // Set block.height (newHeight)
        vm.roll(1000);
        assertEq(stakeTokenAmount, 0);
        RCCStakeInstance.massUpdatePools();
        (
            stakeTokenAddress,
            poolWeight,
            lastRewardBlock,
            accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            stakeTokenAmount /**质押的总代币数量 */,
            minDepositAmount /** 最小质押金额 */,
            unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStakeInstance.pool(0);
        assertEq(minDepositAmount, 100);
        assertEq(unStakeLockedBlocks, 100);
        assertEq(lastRewardBlock, 100);
    }

    function test_SetPoolWeight() public {
        test_AddPool();
        uint256 preTotalPoolWeight = RCCStakeInstance.totalPoolWeight();
        RCCStakeInstance.setPoolWeight(0, 200, false);
        (, uint256 poolWeight, , , , , ) = RCCStakeInstance.pool(0);
        uint256 totalPoolWeight = RCCStakeInstance.totalPoolWeight();
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
        ) = RCCStakeInstance.pool(0);
        uint256 prePoolStakeTokenAmount = stakeTokenAmount;
        assertEq(
            prePoolStakeTokenAmount,
            0,
            unicode"刚创建池子，池子里一个质押也没有"
        );
        (
            uint stakeAmount,
            uint256 finishedRewards,
            uint256 pendingRewards
        ) = RCCStakeInstance.user(0, address(this));
        /** LOG:
         * 这个语法没看懂，加个address this是干啥的？
         * - A:通过使用 address(this)，测试合约可以模拟一个真实用户的行为，查询自己（作为用户）的质押信息
         * - 但老子写这个问题的时候，没明白的是为啥要传两个参数，因为拿数据要拿到最底层，没有中间解构；
         */
        uint256 preStakeAmount = stakeAmount;
        uint256 preFinishedRewards = finishedRewards;
        uint256 prePendingRewards = pendingRewards;
        assertEq(preStakeAmount, 0, unicode"刚创建池子，用户也没质押");

        // ************************************** 第一次质押  **************************************
        (bool success, bytes memory data) = address(RCCStakeInstance).call{
            value: 100
        }(abi.encodeWithSignature("depositETH()"));
        console2.log("depositETH result:", success, string(data));
        /**
         * - 当你在合约外部（比如在测试合约中）访问另一个合约的状态变量时，你实际上是在调用该变量的 getter 函数。这就是为什么我们需要像调用函数那样使用 RCCStakeInstance.pool(0)，而不是 RCCStakeInstance.pool[0]
         * - 外部合约获取一个结构体时，获取的是解构的数据，而不是完整的结构体；
         */
        (
            stakeTokenAddress,
            poolWeight,
            lastRewardBlock,
            accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            stakeTokenAmount /**质押的总代币数量 */,
            minDepositAmount /** 最小质押金额 */,
            unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStakeInstance.pool(0);
        (stakeAmount, finishedRewards, pendingRewards) = RCCStakeInstance.user(
            0,
            address(this)
        );
        // done。如果参数为（0, address(this)，则编译无法通过； 现状是test case 过不去）;
        uint256 expectedStAmount = preStakeAmount + 100;
        uint256 expectedFinishedRCC = preFinishedRewards;
        uint256 expectedTotalStTokenAmount = prePoolStakeTokenAmount + 100;

        assertEq(
            stakeTokenAmount,
            expectedStAmount,
            unicode"池子里该用户总质押更新成功"
        );
        assertEq(
            finishedRewards,
            expectedFinishedRCC,
            "Finished rewards should be correct"
        );
        assertEq(
            stakeTokenAmount,
            expectedTotalStTokenAmount,
            unicode"池子总质押更新成功"
        );
        console2.log(
            "depositETH deposit 100 result:",
            unicode"池子总质押数量",
            stakeTokenAmount
        );
        console2.log(unicode"用户质押数量", stakeAmount);

        // ************************************** 多存几次  **************************************
        (success, data) = address(RCCStakeInstance).call{value: 200 ether}(
            abi.encodeWithSignature("depositETH()")
        );
        console2.log("depositETH2 result:", success, string(data));
        // 数据准备
        expectedStAmount = expectedStAmount + 200 ether;
        expectedTotalStTokenAmount = expectedTotalStTokenAmount + 200 ether;
        (
            stakeTokenAddress,
            poolWeight,
            lastRewardBlock,
            accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            stakeTokenAmount /**质押的总代币数量 */,
            minDepositAmount /** 最小质押金额 */,
            unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStakeInstance.pool(0);
        (stakeAmount, finishedRewards, pendingRewards) = RCCStakeInstance.user(
            0,
            address(this)
        );
        assertEq(
            stakeAmount,
            expectedStAmount,
            unicode"池子里该用户总质押更新成功"
        );
        assertEq(
            expectedTotalStTokenAmount,
            stakeTokenAmount,
            unicode"池子总质押更新成功"
        );
        console2.log(
            "depositETH deposit 200 ether result:",
            unicode"池子总质押数量",
            stakeTokenAmount
        );
        console2.log(unicode"用户质押数量", stakeAmount);
        // 截止到这里都 ok
        vm.roll(2000000);
        // Start recording logs
        RCCStakeInstance.unstake(0, 100);
        (
            stakeTokenAddress,
            poolWeight,
            lastRewardBlock,
            accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            stakeTokenAmount /**质押的总代币数量 */,
            minDepositAmount /** 最小质押金额 */,
            unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStakeInstance.pool(0);
        (stakeAmount, finishedRewards, pendingRewards) = RCCStakeInstance.user(
            0,
            address(this)
        );
        assertEq(stakeAmount, 200 ether, unicode"用户质押更新成功");
        assertEq(stakeTokenAmount, 200 ether, unicode"池子质押更新成功");
        console2.log(
            "unstake 100 result:",
            unicode"池子总质押数量",
            stakeTokenAmount
        );
        console2.log(unicode"用户质押数量", stakeAmount);

        (success, data) = address(RCCStakeInstance).call{value: 300 ether}(
            abi.encodeWithSignature("depositETH()")
        );
        console2.log("depositETH 300 ether result:", success, string(data));

        vm.roll(3000000);
        // TODO: 是这里出了问题
        vm.recordLogs();
        RCCStakeInstance.unstake(0, 100);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        address(RCCStakeInstance).call{value: 400 ether}(
            abi.encodeWithSignature("depositETH()")
        );
        console2.log("depositETH 400 ether result:", success, string(data));

        vm.roll(4000000);
        RCCStakeInstance.unstake(0, 100);
        address(RCCStakeInstance).call{value: 500 ether}(
            abi.encodeWithSignature("depositETH()")
        );
        console2.log("depositETH 500 ether result:", success, string(data));

        vm.roll(5000000);
        RCCStakeInstance.unstake(0, 100);
        address(RCCStakeInstance).call{value: 600 ether}(
            abi.encodeWithSignature("depositETH()")
        );
        console2.log("depositETH 600 ether result:", success, string(data));

        vm.roll(6000000);
        RCCStakeInstance.unstake(0, 100);
        address(RCCStakeInstance).call{value: 700 ether}(
            abi.encodeWithSignature("depositETH()")
        );
        console2.log("depositETH 700 ether result:", success, string(data));
        RCCStakeInstance.withdraw(0);
        // Get recorded logs

        // Print all recorded events
        for (uint i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];
            console2.log("Event:");
            console2.log("  Address:", entry.emitter);
            console2.log("  Topic 1:", vm.toString(entry.topics[0]));
            if (entry.topics.length > 1) {
                console2.log("  Topic 2:", vm.toString(entry.topics[1]));
            }
            if (entry.topics.length > 2) {
                console2.log("  Topic 3:", vm.toString(entry.topics[2]));
            }
            if (entry.topics.length > 3) {
                console2.log("  Topic 4:", vm.toString(entry.topics[2]));
            }
            console2.log("  Data:", vm.toString(entry.data));
        }
        // TODO: 这里不该有一些对于数据的eq校验么？A：这些应该是给后续的测试准备用的；
    }

    function test_Unstake() public {
        test_DepositNativeCurrency();
        vm.roll(1000);
        RCCStakeInstance.unstake(0, 100);
        (
            uint256 stakeAmount,
            uint256 finishedRewards,
            uint256 pendingRewards
        ) = RCCStakeInstance.user(0, address(this));
        assertGt(stakeAmount, 0);
        assertGt(finishedRewards, 0);
        assertGt(pendingRewards, 0);
        (
            address stakeTokenAddress,
            uint256 poolWeight,
            uint256 lastRewardBlock,
            uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */,
            uint256 stakeTokenAmount /**质押的总代币数量 */,
            uint256 minDepositAmount /** 最小质押金额 */,
            uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */
        ) = RCCStakeInstance.pool(0);

        uint256 expectedStakeTokenAmount = 0;
        assertEq(stakeTokenAmount, expectedStakeTokenAmount);
    }

    function test_Withdraw() public {
        test_Unstake();
        // FIXME: 语法还没弄懂
        uint256 preContractBalance = address(RCCStakeInstance).balance;
        uint256 preUserBalance = address(this).balance;

        vm.roll(10000);
        RCCStakeInstance.withdraw(0);

        uint256 postContractBalance = address(RCCStakeInstance).balance;
        uint256 postUserBalance = address(this).balance;
        // Asserts left is strictly less than right.
        assertLt(postContractBalance, preContractBalance);
        // Asserts left is strictly greater than right.
        assertGt(postUserBalance, preUserBalance);
    }

    function test_claimAfterDeposit() public {
        test_DepositNativeCurrency();
        RCCInstance.transfer(address(RCCStakeInstance), 100000000000);
        uint256 preUserRCCBalance = RCCInstance.balanceOf(address(this));

        vm.roll(10000);
        RCCStakeInstance.claim(0);

        uint256 postUserRCCBalance = RCCInstance.balanceOf(address(this));
        assertGt(postUserRCCBalance, preUserRCCBalance);
    }

    function addPool(uint256 index, address stakeTokenAddress) public {
        address _stakeTokenAddress = stakeTokenAddress;
        uint256 _poolWeight = 100;
        uint256 _minDepositAmount = 100;
        uint256 _withdrawLockedBlocks = 100;
        bool _update = true;
        RCCStakeInstance.addPool(
            _stakeTokenAddress,
            _poolWeight,
            _minDepositAmount,
            _withdrawLockedBlocks,
            _update
        );
    }
}
