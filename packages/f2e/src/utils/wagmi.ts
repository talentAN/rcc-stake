import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'viem';
import { Chain, arbitrum, base, mainnet, optimism, polygon, sepolia } from 'wagmi/chains';

// 定义本地开发网络
const localNetwork: Chain = {
  id: 31337,
  name: 'Local Network',
  nativeCurrency: {
    decimals: 18,
    name: 'Ethereum',
    symbol: 'ETH'
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] }
  }
};

// 前端用的环境变量，得用 NEXT_PUBLIC 开头
export const config = getDefaultConfig({
  appName: 'Rcc Stake',
  projectId: process.env.NEXT_PUBLIC_RAINBOWKIT_PROJECT_ID as string,
  chains: [localNetwork, sepolia, arbitrum, base, mainnet, optimism, polygon],
  transports: {
    [sepolia.id]: http('https://sepolia.infura.io/v3/d8ed0bd1de8242d998a1405b6932ab33'),
    [localNetwork.id]: http('http://127.0.0.1:8545')
  },
  ssr: true
});

export const defaultChainId: number = localNetwork.id;
