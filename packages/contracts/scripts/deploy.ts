import hre, { ethers, upgrades } from 'hardhat';
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
    //  部署获取到的Rcc Token 地址，所以，得先把 RCC token部署了
    const RCCToken = await hre.viem.deployContract('RccToken');
    console.log('RCCToken deployed to:', RCCToken.address);
    const rewardTokenAddress = RCCToken.address;
    // 质押起始区块高度,可以去sepolia上面读取最新的区块高度
    const startBlock = 6529999;
    // 质押结束的区块高度,sepolia 出块时间是12s,想要质押合约运行x秒,那么endBlock = startBlock+x/12
    const endBlock = 9529999;
    // 每个区块奖励的Rcc token的数量
    const RccPerBlock = '20000000000000000';

    console.log('Deploying RCCStake...');
    // 部署可升级的 RCCStake 合约
    const RCCStakeFactory = await ethers.getContractFactory('RCCStake');

    const RCCStake = await upgrades.deployProxy(
      RCCStakeFactory,
      [rewardTokenAddress, startBlock, endBlock, RccPerBlock],
      { initializer: 'initialize' }
    );

    // 等待交易被确认
    await RCCStake.waitForDeployment();

    // 获取部署后的合约地址
    const rccStakeAddress = await RCCStake.getAddress();
    console.log('RCCStake deployed to:', rccStakeAddress);
    // 更新前端的本地环境变量
    writeLocalEnv(
      {
        token: RCCToken.address,
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
