import type { HardhatUserConfig } from 'hardhat/config';
import dotenv from 'dotenv';
import '@nomicfoundation/hardhat-toolbox-viem';
import '@nomicfoundation/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
// import '@nomiclabs/hardhat-waffle';
// 上面的狗蛋是本地调试用的，注释了没法命令行调试了就；

dotenv.config();

const { SEPOLIA_RPC_URL = '', PRIVATE_KEY, ETHERSCAN_API_KEY, PRIVATE_KEY_SLAVE } = process.env; // 读取环境变量

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
    hardhat: {
      forking: {
        url: SEPOLIA_RPC_URL,
        blockNumber: 1350000 // 可选，您可以指定要 fork 的区块高度
      },
      chainId: 1337 // 你自定义的 chainId
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [`0x${PRIVATE_KEY_SLAVE}`] // 注意将 PRIVATE_KEY 前加上 "0x"
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },
  sourcify: {
    enabled: true
  }
};

// 配置 OpenZeppelin 插件
process.env.DISABLE_UPGRADES_WARNINGS = 'true';
process.env.DISABLE_UPGRADES_UNSAFE_ALLOW = 'true';

export default config;
