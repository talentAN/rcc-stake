import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'viem';
import { arbitrum, base, mainnet, optimism, polygon, sepolia } from 'wagmi/chains';

// 前端用的环境变量，得用 NEXT_PUBLIC 开头
export const config = getDefaultConfig({
  appName: 'Rcc Stake',
  projectId: process.env.NEXT_PUBLIC_RAINBOWKIT_PROJECT_ID as string,
  chains: [sepolia, arbitrum, base, mainnet, optimism, polygon],
  transports: {
    [sepolia.id]: http('https://sepolia.infura.io/v3/d8ed0bd1de8242d998a1405b6932ab33')
  },
  ssr: true
});

export const defaultChainId: number = sepolia.id;
