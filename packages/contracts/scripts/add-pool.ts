const { ethers } = require('hardhat');

// 替换为你的合约地址
const contractAddress = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

// 替换为合约的 ABI
const contractABI = [
  'function addPool(address _stakeTokenAddress,uint256 _poolWeight,uint256 _minDepositAmount,uint256 _unStakeLockedBlocks,bool _withUpdate)'
];
async function main() {
  try {
    const contract = await ethers.getContractAt(contractABI, contractAddress);
    console.log(contract);
    return;
    const tx = await contract.addPool('0x0', 100, 100, 100, false);
    await tx.wait();
    console.log('add Pool成功:', tx);
  } catch (error) {
    console.log('add 失败:', error);
  }
}

main();
