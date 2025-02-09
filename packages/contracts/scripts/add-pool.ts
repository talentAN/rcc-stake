import { ethers } from 'hardhat';

// 替换为你的合约地址
const contractAddress = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

// 替换为合约的 ABI
const contractABI = [
  'function addPool(address _stakeTokenAddress,uint256 _poolWeight,uint256 _minDepositAmount,uint256 _unStakeLockedBlocks,bool _withUpdate)'
];
async function main() {
  try {
    // 获取网络连接
    const [signer] = await ethers.getSigners();
    // 使用 signer 连接到合约
    const contract = new ethers.Contract(contractAddress, contractABI, signer);
    console.log('Adding pool...');
    const tx = await contract.addPool(ethers.ZeroAddress, 100, 100, 100, false);
    console.log('Transaction sent:', tx.hash);
    console.log('Pool added successfully');
  } catch (error) {
    console.error('Failed to add pool:', error);
  }
}

main().catch(error => {
  console.error('add fail ', error);
  process.exitCode = 1;
});
