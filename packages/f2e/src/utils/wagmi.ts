import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { http } from 'viem';
import { arbitrum, base, mainnet, optimism, polygon, sepolia } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Rcc Stake',
  projectId: process.env.NEXT_PUBLIC_RAINBOWKIT_PROJECT_ID as string,
  chains: [sepolia],
  transports: {
    [sepolia.id]: http('https://sepolia.infura.io/v3/d8ed0bd1de8242d998a1405b6932ab33')
  },
  ssr: true
});

export const defaultChainId: number = sepolia.id;
