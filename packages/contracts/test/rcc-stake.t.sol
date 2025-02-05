// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// TODO: 这个测试文件只能forge跑吧，hardhat能跑么？

import {Test, console2, Vm} from "forge-std/Test.sol";
import {RCCStake} from "../contracts/RCCStake.sol";
import {RccToken} from "../contracts/RccToken.sol";

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
        assertEq(lastRewardBlock, 1000);
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

    function depositAndCheck(
        uint256 amount,
        uint256 expectedUserStake,
        uint256 expectedFinishedRewards
    ) private {
        (bool success, ) = address(RCCStakeInstance).call{value: amount}(
            abi.encodeWithSignature("depositETH()")
        );
        require(success, "Deposit failed");

        checkPoolAndUserState(
            expectedUserStake,
            expectedFinishedRewards,
            expectedUserStake,
            0
        );
    }

    function unstakeAndCheck(
        uint256 amount,
        uint256 expectedUserStake,
        uint256 expectedPoolStake
    ) private {
        RCCStakeInstance.unstake(0, amount);

        (uint256 stakeAmount, , ) = RCCStakeInstance.user(0, address(this));
        (, , , , uint256 stakeTokenAmount, , ) = RCCStakeInstance.pool(0);

        assertEq(stakeAmount, expectedUserStake, unicode"用户质押更新成功");
        assertEq(
            stakeTokenAmount,
            expectedPoolStake,
            unicode"池子质押更新成功"
        );
    }

    function checkPoolAndUserState(
        uint256 expectedUserStake,
        uint256 expectedFinishedRewards,
        uint256 expectedPoolStake,
        uint256 expectedPendingRewards
    ) private {
        (
            uint256 stakeAmount,
            uint256 finishedRewards,
            uint256 pendingRewards
        ) = RCCStakeInstance.user(0, address(this));
        (, , , , uint256 stakeTokenAmount, , ) = RCCStakeInstance.pool(0);

        assertEq(stakeAmount, expectedUserStake, unicode"用户质押数量不匹配");
        assertEq(
            finishedRewards,
            expectedFinishedRewards,
            unicode"已完成奖励不匹配"
        );
        assertEq(
            pendingRewards,
            expectedPendingRewards,
            unicode"待领取奖励不匹配"
        );
        assertEq(
            stakeTokenAmount,
            expectedPoolStake,
            unicode"池子总质押数量不匹配"
        );
    }

    function multipleDepositsAndUnstakes() private {
        uint256[5] memory deposits;
        deposits[0] = 300 ether;
        deposits[1] = 400 ether;
        deposits[2] = 500 ether;
        deposits[3] = 600 ether;
        deposits[4] = 700 ether;

        uint256[5] memory blockNumbers;
        blockNumbers[0] = 3000000;
        blockNumbers[1] = 4000000;
        blockNumbers[2] = 5000000;
        blockNumbers[3] = 6000000;
        blockNumbers[4] = 7000000;

        for (uint256 i = 0; i < deposits.length; i++) {
            vm.roll(blockNumbers[i]);
            RCCStakeInstance.unstake(0, 100);

            (bool success, ) = address(RCCStakeInstance).call{
                value: deposits[i]
            }(abi.encodeWithSignature("depositETH()"));
            require(success, "Deposit failed");
            // 你可以在这里添加更多具体的检查
        }
    }

    function test_DepositNativeCurrency() public {
        test_AddPool();

        // Initial checks
        checkPoolAndUserState(0, 0, 0, 0);

        // First deposit
        depositAndCheck(100, 100, 0);

        // Second deposit
        depositAndCheck(200 ether, 200 ether + 100, 0);

        // Unstake and deposit multiple times
        vm.roll(2000000);

        unstakeAndCheck(100, 200 ether, 200 ether);

        multipleDepositsAndUnstakes();

        RCCStakeInstance.withdraw(0);
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
        assertGt(stakeTokenAmount, expectedStakeTokenAmount);
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
        assertLe(postContractBalance, preContractBalance);
        // Asserts left is strictly greater than right.
        assertGe(postUserBalance, preUserBalance);
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

    // function addPool(uint256 index, address stakeTokenAddress) public {
    //     address _stakeTokenAddress = stakeTokenAddress;
    //     uint256 _poolWeight = 100;
    //     uint256 _minDepositAmount = 100;
    //     uint256 _withdrawLockedBlocks = 100;
    //     bool _update = true;
    //     RCCStakeInstance.addPool(
    //         _stakeTokenAddress,
    //         _poolWeight,
    //         _minDepositAmount,
    //         _withdrawLockedBlocks,
    //         _update
    //     );
    // }
}
