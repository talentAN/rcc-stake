import { useMemo } from 'react';
import { Abi, Address, getContract, Client } from 'viem';
import { useChainId, usePublicClient, useWalletClient } from 'wagmi';
import { StakeContractAddress } from '../utils/env';
import stakeData from '../../../contracts/artifacts/contracts/RCCStake.sol/RCCStake.json';

export function useContract<TAbi extends Abi>(
  addressOrAddressMap?: Address | { [chainId: number]: Address },
  abi?: TAbi,
  options?: { chainId?: number }
) {
  const chainId = useChainId();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();

  return useMemo(() => {
    if (!addressOrAddressMap || !abi || !chainId) return null;

    let address: Address | undefined;
    if (typeof addressOrAddressMap === 'string') {
      address = addressOrAddressMap;
    } else {
      address = addressOrAddressMap[chainId];
    }

    if (!address) return null;

    try {
      return getContract({
        address,
        abi,
        client: publicClient as Client
      });
    } catch (error) {
      console.error('Failed to get contract', error);
      return null;
    }
  }, [addressOrAddressMap, abi, chainId, publicClient, walletClient]);
}

export const useStakeContract = () => {
  return useContract(StakeContractAddress, stakeData.abi as Abi);
};
