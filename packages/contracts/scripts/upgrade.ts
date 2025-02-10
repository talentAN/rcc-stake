import { ethers, upgrades } from 'hardhat';
import { readFileSync, writeFileSync } from 'fs';

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

async function main() {
  try {
    // 部署 RccToken
    const RccTokenFactory = await ethers.getContractFactory('RccToken');
    const RCCToken = await RccTokenFactory.deploy();
    await RCCToken.waitForDeployment();
    const RCCTokenAddress = await RCCToken.getAddress();
    console.log('RCCToken deployed to:', RCCTokenAddress);

    // 设置基本条件
    const rewardTokenAddress = RCCTokenAddress;
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
        initializer: 'initialize',
        kind: 'uups'
      }
    );

    // 等待交易被确认
    await RCCStake.waitForDeployment();

    // 获取部署后的合约地址
    const rccStakeAddress = await RCCStake.getAddress();
    const code = await ethers.provider.getCode(rccStakeAddress);
    console.log('RCCStake code:', code);
    console.log('RCCStake deployed to:', rccStakeAddress);
    // 更新前端的本地环境变量
    writeLocalEnv(
      {
        token: rewardTokenAddress,
        stake: rccStakeAddress
      },
      '../f2e/.env.local'
    );
  } catch (error) {
    console.error('Error during deployment:', error);
    process.exit(1);
  }
}

main().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
