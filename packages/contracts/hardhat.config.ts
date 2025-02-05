import type { HardhatUserConfig } from 'hardhat/config';
import dotenv from 'dotenv';
import '@nomicfoundation/hardhat-toolbox-viem';
import '@nomicfoundation/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';

dotenv.config();

const { SEPOLIA_RPC_URL, ETH_RPC_URL, PRIVATE_KEY } = process.env; // 读取环境变量

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.22',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200 // 设置 runs 值
      }
    }
  },
  networks: {
    ropsten: {
      url: SEPOLIA_RPC_URL,
      accounts: [`0x${PRIVATE_KEY}`] // 注意将 PRIVATE_KEY 前加上 "0x"
    }
  }
};

export default config;
