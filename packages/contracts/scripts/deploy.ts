import hre, { ethers, upgrades } from 'hardhat';

async function main() {
  //  部署获取到的Rcc Token 地址，所以TODO: 首现，得先把 RCC token部署了
  const RCCToken = await hre.viem.deployContract('RccToken');
  console.log('RCCToken deployed to:', RCCToken.address);
  const rewardTokenAddress = RCCToken.address;
  // 质押起始区块高度,可以去sepolia上面读取最新的区块高度
  const startBlock = 6529999;
  // 质押结束的区块高度,sepolia 出块时间是12s,想要质押合约运行x秒,那么endBlock = startBlock+x/12
  const endBlock = 9529999;
  // 每个区块奖励的Rcc token的数量
  const RccPerBlock = '20000000000000000';

  // 部署可升级的 RCCStake 合约
  const RCCStakeFactory = await ethers.getContractFactory('RCCStake');
  const RCCStake = await upgrades.deployProxy(
    RCCStakeFactory,
    [rewardTokenAddress, startBlock, endBlock, RccPerBlock],
    { initializer: 'initialize' }
  );
  // const RCCStake = await hre.viem.deployContract('RCCStake', [
  //   rewardTokenAddress,
  //   startBlock,
  //   endBlock,
  //   RccPerBlock
  // ]);
  console.log('RCCStake deployed to:', RCCStake.address);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
