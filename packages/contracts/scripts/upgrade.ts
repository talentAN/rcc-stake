import { ethers, upgrades } from 'hardhat';
import { readFileSync } from 'fs';
import path from 'path';

// 从环境变量文件读取代理合约地址
const getProxyAddress = (filePath: string): string => {
  try {
    const fileContent = readFileSync(filePath, 'utf8');
    const match = fileContent.match(/NEXT_PUBLIC_RCC_STAKE_ADDRESS=(.*)/);
    if (!match) {
      throw new Error('找不到质押合约地址在环境变量文件中');
    }
    return match[1];
  } catch (error) {
    console.error('读取环境变量文件失败:', error);
    throw error;
  }
};

async function main() {
  try {
    // 获取当前代理合约地址
    const proxyAddress = getProxyAddress(path.join(__dirname, '..', '..', 'f2e', '.env.local'));
    console.log('Current proxy address:', proxyAddress);

    // 获取部署者账户
    const deployer = await ethers.provider.getSigner();
    const deployerAddress = await deployer.getAddress();

    // 获取当前合约实例
    const RCCStake = await ethers.getContractAt('RCCStake', proxyAddress);

    // 验证升级权限
    const UPGRADE_ROLE = await RCCStake.UPGRADE_ROLE();
    const hasUpgradeRole = await RCCStake.hasRole(UPGRADE_ROLE, deployerAddress);
    if (!hasUpgradeRole) {
      throw new Error('部署者没有升级权限');
    }

    console.log('Deploying new implementation...');
    // 准备新的实现合约
    const RCCStakeFactory = await ethers.getContractFactory('RCCStake');

    // 执行升级
    console.log('Upgrading RCCStake...');
    const upgradedRCCStake = await upgrades.upgradeProxy(proxyAddress, RCCStakeFactory);

    // 等待升级交易被确认
    await upgradedRCCStake.waitForDeployment();

    // 验证升级结果
    console.log('Verifying upgrade...');

    // 验证新合约地址
    const newImplementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log('New implementation address:', newImplementationAddress);

    // 验证管理员地址
    const adminAddress = await upgrades.erc1967.getAdminAddress(proxyAddress);
    console.log('Proxy admin address:', adminAddress);

    // 验证 ETH 池子状态
    const pool = await upgradedRCCStake.pool(0);
    console.log('ETH Pool details after upgrade:', {
      stakeToken: pool.stakeTokenAmount,
      weight: pool.poolWeight,
      minDepositAmount: pool.minDepositAmount,
      unStakeLockedBlocks: pool.unStakeLockedBlocks
    });

    console.log('Upgrade completed successfully');
  } catch (error) {
    console.error('Error during upgrade:', error);
    process.exit(1);
  }
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
