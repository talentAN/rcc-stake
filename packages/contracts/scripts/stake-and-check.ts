import { abi as contractABI } from '../artifacts/contracts/RCCStake.sol/RCCStake.json';
import hre from 'hardhat';
import { formatEther } from 'viem';

// 替换为你的合约地址
const contractAddress = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';
// 狗日的，这个格式的abi才能正常执行，直接引入JSON不行，为什么？
// const contractABI = [
//   'function addPool(address _stakeTokenAddress,uint256 _poolWeight,uint256 _minDepositAmount,uint256 _unStakeLockedBlocks,bool _withUpdate)',
//   'function stakingBalance(uint256 _pid, address _user) view returns (uint256)'
// ];

async function main() {
  try {
    // 获取账户
    const [account] = await hre.viem.getWalletClients();
    const publicClient = await hre.viem.getPublicClient();

    // 检查网络
    const chain = await publicClient.getChainId();
    console.log('当前网络 chainId:', chain);

    console.log('合约地址:', contractAddress);

    // 创建合约实例
    const contract = await hre.viem.getContractAt('RCCStake', contractAddress);

    const address = account.account.address;
    console.log('查询余额中...');
    console.log('address', address);

    // 先检查合约是否存在
    const code = await publicClient.getCode({ address: contractAddress });
    console.log('RCCStake code:', code);
    if (!code) {
      throw new Error('合约未部署到此地址');
    }

    // 尝试获取池子数量
    const poolLength = await contract.read.getPoolLength();
    console.log('池子数量:', poolLength?.toString());

    // 再查询余额
    const balance = await contract.read.stakingBalance([0n, address]);
    console.log('balance', balance);

    // 将余额转换为更易读的格式
    const balanceInEther = formatEther(balance as any);
    console.log(`地址 ${address} 的质押余额: ${balanceInEther} ETH`);
  } catch (error) {
    console.error('查询余额失败:', error);
  }
}

main().catch(error => {
  console.error('脚本执行失败:', error);
  process.exitCode = 1;
});
