const { ethers } = require('hardhat');

// 替换为你的合约地址
const contractAddress = '0x0165878A594ca255338adfa4d48449f69242Eb8F';

// 替换为合约的 ABI
const contractABI = [
  'function addPool(address _stakeTokenAddress,uint256 _poolWeight,uint256 _minDepositAmount,uint256 _unStakeLockedBlocks,bool _withUpdate'
];
async function main() {
  const contract = await ethers.getContractAt(contractABI, contractAddress);
  const tx = await contract.addPool();
  await tx.wait();
  console.log('Method b was called with value 100');
}

main();
