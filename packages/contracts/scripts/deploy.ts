import { ethers, upgrades } from 'hardhat';
import { readFileSync, writeFileSync } from 'fs';
import path from 'path';

const writeLocalEnv = (address: any, filePath: string) => {
  try {
    // 读取 .env 文件内容
    const fileContent = readFileSync(filePath, 'utf8');
    // 使用正则表达式替换 ADDRESS 的值
    const updatedContent = fileContent
      .replace(
        /NEXT_PUBLIC_RCC_TOKEN_ADDRESS=.*/g,
        `NEXT_PUBLIC_RCC_TOKEN_ADDRESS=${address.token}`
      )
      .replace(
        /NEXT_PUBLIC_RCC_STAKE_ADDRESS=.*/g,
        `NEXT_PUBLIC_RCC_STAKE_ADDRESS=${address.stake}`
      );
    // 重新写入到 .env 文件
    writeFileSync(filePath, updatedContent, 'utf8');

    console.log('成功更新 .env.local 文件!');
  } catch (error) {
    console.error('写入 .env.local 文件出错:', error);
  }
};

// 部署 RccToken
const deployRccToken = async () => {
  const RccTokenFactory = await ethers.getContractFactory('RccToken');
  const RCCToken = await RccTokenFactory.deploy();
  await RCCToken.waitForDeployment();
  const RCCTokenAddress = await RCCToken.getAddress();
  console.log('RCCToken deployed to:', RCCTokenAddress);
  return RCCTokenAddress;
};

async function main() {
  try {
    // 设置基本条件
    const rewardTokenAddress = await deployRccToken();
    // 质押起始区块高度,可以去sepolia上面读取最新的区块高度
    const startBlock = 6529999;
    // 质押结束的区块高度,sepolia 出块时间是12s,想要质押合约运行x秒,那么endBlock = startBlock+x/12
    const endBlock = 9529999;
    // 每个区块奖励的Rcc token的数量
    const RccPerBlock = '20000000000000000';

    // 部署质押合约
    console.log('Deploying RCCStake...');
    const RCCStakeFactory = await ethers.getContractFactory('RCCStake');

    const RCCStake = await upgrades.deployProxy(
      RCCStakeFactory,
      [rewardTokenAddress, startBlock, endBlock, RccPerBlock],
      {
        initializer: 'initialize'
      }
    );

    // 等待交易被确认
    await RCCStake.waitForDeployment();

    // 获取部署后的合约地址
    const rccStakeAddress = await RCCStake.getAddress();

    // 设置初始 ETH 质押池
    console.log('Setting up initial ETH staking pool...');
    const minDepositAmount = ethers.parseEther('0.000001'); // 最小质押数量，比如0.1 ETH
    const unStakeLockedBlocks = 100; // 解锁所需区块数
    const poolWeight = 1000; // 池子权重
    await RCCStake.addPool(
      ethers.ZeroAddress, // ETH pool 的 stakeTokenAddress 必须是 0x0
      poolWeight,
      minDepositAmount,
      unStakeLockedBlocks,
      true // withUpdate
    );

    console.log('ETH staking pool initialized');

    // 设置角色权限
    const deployer = await ethers.provider.getSigner();
    const deployerAddress = await deployer.getAddress();

    const ADMIN_ROLE = await RCCStake.ADMIN_ROLE();
    const UPGRADE_ROLE = await RCCStake.UPGRADE_ROLE();

    await RCCStake.grantRole(ADMIN_ROLE, deployerAddress);
    await RCCStake.grantRole(UPGRADE_ROLE, deployerAddress);

    console.log('Roles granted to deployer:', deployerAddress);

    // 更新前端的本地环境变量
    writeLocalEnv(
      {
        token: rewardTokenAddress,
        stake: rccStakeAddress
      },
      path.join(__dirname, '..', '..', 'f2e', '.env.local')
    );

    // 验证部署结果
    console.log('Verifying deployment...');

    // 验证 ETH 池子
    const pool = await RCCStake.pool(0);
    console.log('ETH Pool details:', {
      stakeToken: pool.stakeTokenAmount,
      weight: pool.poolWeight,
      minDepositAmount: pool.minDepositAmount,
      unStakeLockedBlocks: pool.unStakeLockedBlocks
    });

    // 验证角色
    const hasAdminRole = await RCCStake.hasRole(ADMIN_ROLE, deployerAddress);
    const hasUpgradeRole = await RCCStake.hasRole(UPGRADE_ROLE, deployerAddress);
    console.log('Role verification:', {
      hasAdminRole,
      hasUpgradeRole
    });

    console.log('Deployment and initialization completed successfully');
  } catch (error) {
    console.error('Error during deployment:', error);
    process.exit(1);
  }
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
