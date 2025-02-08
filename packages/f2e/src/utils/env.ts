import { Address, zeroAddress } from 'viem';

export const StakeContractAddress =
  (process.env.NEXT_PUBLIC_RCC_STAKE_ADDRESS as Address) || zeroAddress;
