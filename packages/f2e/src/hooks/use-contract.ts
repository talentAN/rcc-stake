import { useMemo } from 'react';
import { Abi, Address } from 'viem';
import { useChainId, useWalletClient } from 'wagmi';
import { getContract } from '../utils/contract-helper';
import { StakeContractAddress } from '../utils/env';
import stakeData from '../../../contracts/artifacts/contracts/RCCStake.sol/RCCStake.json';

type UseContractOptions = {
  chainId?: number;
};

export function useContract<TAbi extends Abi>(
  addressOrAddressMap?: Address | { [chainId: number]: Address },
  abi?: TAbi,
  options?: UseContractOptions
) {
  const currentChainId = useChainId();
  const chainId = options?.chainId || currentChainId;
  const { data: walletClient } = useWalletClient();

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
        abi,
        address,
        chainId,
        signer: walletClient ?? undefined
      });
    } catch (error) {
      console.error('Failed to get contract', error);
      return null;
    }
  }, [addressOrAddressMap, abi, chainId, walletClient]);
}

const abi = [
  { inputs: [], name: 'AccessControlBadConfirmation', type: 'error' },
  {
    inputs: [
      { internalType: 'address', name: 'account', type: 'address' },
      { internalType: 'bytes32', name: 'neededRole', type: 'bytes32' }
    ],
    name: 'AccessControlUnauthorizedAccount',
    type: 'error'
  },
  {
    inputs: [{ internalType: 'address', name: 'target', type: 'address' }],
    name: 'AddressEmptyCode',
    type: 'error'
  },
  {
    inputs: [{ internalType: 'address', name: 'implementation', type: 'address' }],
    name: 'ERC1967InvalidImplementation',
    type: 'error'
  },
  { inputs: [], name: 'ERC1967NonPayable', type: 'error' },
  { inputs: [], name: 'EnforcedPause', type: 'error' },
  { inputs: [], name: 'ExpectedPause', type: 'error' },
  { inputs: [], name: 'FailedCall', type: 'error' },
  { inputs: [], name: 'InvalidInitialization', type: 'error' },
  { inputs: [], name: 'NotInitializing', type: 'error' },
  {
    inputs: [{ internalType: 'address', name: 'token', type: 'address' }],
    name: 'SafeERC20FailedOperation',
    type: 'error'
  },
  { inputs: [], name: 'UUPSUnauthorizedCallContext', type: 'error' },
  {
    inputs: [{ internalType: 'bytes32', name: 'slot', type: 'bytes32' }],
    name: 'UUPSUnsupportedProxiableUUID',
    type: 'error'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'stakeTokenAddress', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'poolWeight', type: 'uint256' },
      { indexed: true, internalType: 'uint256', name: 'lastRewardBlock', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'minDepositAmount', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'unStakeLockedBlocks', type: 'uint256' }
    ],
    name: 'AddPool',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'RccReward', type: 'uint256' }
    ],
    name: 'Claim',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'Deposit',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'address', name: 'pid', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'GetRewards',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: false, internalType: 'uint64', name: 'version', type: 'uint64' }],
    name: 'Initialized',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: false, internalType: 'address', name: 'account', type: 'address' }],
    name: 'Paused',
    type: 'event'
  },
  { anonymous: false, inputs: [], name: 'PausedClaim', type: 'event' },
  { anonymous: false, inputs: [], name: 'PausedWithdraw', type: 'event' },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'RequestUnstake',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { indexed: true, internalType: 'bytes32', name: 'previousAdminRole', type: 'bytes32' },
      { indexed: true, internalType: 'bytes32', name: 'newAdminRole', type: 'bytes32' }
    ],
    name: 'RoleAdminChanged',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { indexed: true, internalType: 'address', name: 'account', type: 'address' },
      { indexed: true, internalType: 'address', name: 'sender', type: 'address' }
    ],
    name: 'RoleGranted',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { indexed: true, internalType: 'address', name: 'account', type: 'address' },
      { indexed: true, internalType: 'address', name: 'sender', type: 'address' }
    ],
    name: 'RoleRevoked',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, internalType: 'uint256', name: 'endBlock', type: 'uint256' }],
    name: 'SetEndBlock',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'poolWeight', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'totalPoolWeight', type: 'uint256' }
    ],
    name: 'SetPoolWeight',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, internalType: 'contract IERC20', name: 'RCC', type: 'address' }],
    name: 'SetRCC',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, internalType: 'uint256', name: 'rccPerBlock', type: 'uint256' }],
    name: 'SetRCCPerBlock',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, internalType: 'uint256', name: 'startBlock', type: 'uint256' }],
    name: 'SetStartBlock',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'address', name: 'pid', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'Stake',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'address', name: 'pid', type: 'address' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
    ],
    name: 'UnStake',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: false, internalType: 'address', name: 'account', type: 'address' }],
    name: 'Unpaused',
    type: 'event'
  },
  { anonymous: false, inputs: [], name: 'UnpausedClaim', type: 'event' },
  { anonymous: false, inputs: [], name: 'UnpausedWithdraw', type: 'event' },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: true, internalType: 'uint256', name: 'lastRewardBlock', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'totalRCC', type: 'uint256' }
    ],
    name: 'UpdatePool',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: true, internalType: 'uint256', name: 'minDepositAmount', type: 'uint256' },
      { indexed: true, internalType: 'uint256', name: 'unStakeLockedBlocks', type: 'uint256' }
    ],
    name: 'UpdatePoolInfo',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [{ indexed: true, internalType: 'address', name: 'implementation', type: 'address' }],
    name: 'Upgraded',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: 'address', name: 'user', type: 'address' },
      { indexed: true, internalType: 'uint256', name: 'poolId', type: 'uint256' },
      { indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' },
      { indexed: true, internalType: 'uint256', name: 'blockNumber', type: 'uint256' }
    ],
    name: 'Withdraw',
    type: 'event'
  },
  { stateMutability: 'payable', type: 'fallback' },
  {
    inputs: [],
    name: 'ADMIN_ROLE',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'DEFAULT_ADMIN_ROLE',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'ETH_PID',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'RCC',
    outputs: [{ internalType: 'contract IERC20', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'UPGRADE_INTERFACE_VERSION',
    outputs: [{ internalType: 'string', name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'UPGRADE_ROLE',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'address', name: '_stakeTokenAddress', type: 'address' },
      { internalType: 'uint256', name: '_poolWeight', type: 'uint256' },
      { internalType: 'uint256', name: '_minDepositAmount', type: 'uint256' },
      { internalType: 'uint256', name: '_unStakeLockedBlocks', type: 'uint256' },
      { internalType: 'bool', name: '_withUpdate', type: 'bool' }
    ],
    name: 'addPool',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '_pid', type: 'uint256' }],
    name: 'claim',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'claimPaused',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_pid', type: 'uint256' },
      { internalType: 'uint256', name: '_amount', type: 'uint256' }
    ],
    name: 'deposit',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  { inputs: [], name: 'depositETH', outputs: [], stateMutability: 'payable', type: 'function' },
  {
    inputs: [],
    name: 'endBlock',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_from', type: 'uint256' },
      { internalType: 'uint256', name: '_to', type: 'uint256' }
    ],
    name: 'getMultiplier',
    outputs: [{ internalType: 'uint256', name: 'multiplier', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_poolId', type: 'uint256' },
      { internalType: 'address', name: '_user', type: 'address' }
    ],
    name: 'getPendingRCC',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'getPoolLength',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'bytes32', name: 'role', type: 'bytes32' }],
    name: 'getRoleAdmin',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { internalType: 'address', name: 'account', type: 'address' }
    ],
    name: 'grantRole',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { internalType: 'address', name: 'account', type: 'address' }
    ],
    name: 'hasRole',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'contract IERC20', name: '_RCC', type: 'address' },
      { internalType: 'uint256', name: '_startBlock', type: 'uint256' },
      { internalType: 'uint256', name: '_endBlock', type: 'uint256' },
      { internalType: 'uint256', name: '_rccPerBlock', type: 'uint256' }
    ],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'massUpdatePools',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'pauseWithdraw',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'paused',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_poolId', type: 'uint256' },
      { internalType: 'address', name: '_user', type: 'address' },
      { internalType: 'uint256', name: '_blockNumber', type: 'uint256' }
    ],
    name: 'pendingRCCByBlockNumber',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    name: 'pool',
    outputs: [
      { internalType: 'address', name: 'stakeTokenAddress', type: 'address' },
      { internalType: 'uint256', name: 'poolWeight', type: 'uint256' },
      { internalType: 'uint256', name: 'lastRewardBlock', type: 'uint256' },
      { internalType: 'uint256', name: 'accumulateRewardsPerStake', type: 'uint256' },
      { internalType: 'uint256', name: 'stakeTokenAmount', type: 'uint256' },
      { internalType: 'uint256', name: 'minDepositAmount', type: 'uint256' },
      { internalType: 'uint256', name: 'unStakeLockedBlocks', type: 'uint256' }
    ],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'proxiableUUID',
    outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'rccPerBlock',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { internalType: 'address', name: 'callerConfirmation', type: 'address' }
    ],
    name: 'renounceRole',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'bytes32', name: 'role', type: 'bytes32' },
      { internalType: 'address', name: 'account', type: 'address' }
    ],
    name: 'revokeRole',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '_endBlock', type: 'uint256' }],
    name: 'setEndBlock',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_poolId', type: 'uint256' },
      { internalType: 'uint256', name: '_poolWeight', type: 'uint256' },
      { internalType: 'bool', name: '_withUpdate', type: 'bool' }
    ],
    name: 'setPoolWeight',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'contract IERC20', name: '_RCC', type: 'address' }],
    name: 'setRCC',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '_rccPerBlock', type: 'uint256' }],
    name: 'setRCCPerBlock',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '_startBlock', type: 'uint256' }],
    name: 'setStartBlock',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_pid', type: 'uint256' },
      { internalType: 'address', name: '_user', type: 'address' }
    ],
    name: 'stakingBalance',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'startBlock',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'bytes4', name: 'interfaceId', type: 'bytes4' }],
    name: 'supportsInterface',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'toggleClaimPause',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'toggleWithdrawPause',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [],
    name: 'totalPoolWeight',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_pid', type: 'uint256' },
      { internalType: 'uint256', name: '_amount', type: 'uint256' }
    ],
    name: 'unstake',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '_pid', type: 'uint256' }],
    name: 'updatePool',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_poolId', type: 'uint256' },
      { internalType: 'uint256', name: '_minDepositAmount', type: 'uint256' },
      { internalType: 'uint256', name: '_unStakeLockedBlocks', type: 'uint256' }
    ],
    name: 'updatePool',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'address', name: 'newImplementation', type: 'address' },
      { internalType: 'bytes', name: 'data', type: 'bytes' }
    ],
    name: 'upgradeToAndCall',
    outputs: [],
    stateMutability: 'payable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '', type: 'uint256' },
      { internalType: 'address', name: '', type: 'address' }
    ],
    name: 'user',
    outputs: [
      { internalType: 'uint256', name: 'stakeAmount', type: 'uint256' },
      { internalType: 'uint256', name: 'finishedRewards', type: 'uint256' },
      { internalType: 'uint256', name: 'pendingRewards', type: 'uint256' }
    ],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [{ internalType: 'uint256', name: '_pid', type: 'uint256' }],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'uint256', name: '_poolId', type: 'uint256' },
      { internalType: 'address', name: '_user', type: 'address' }
    ],
    name: 'withdrawAmount',
    outputs: [
      { internalType: 'uint256', name: 'requestAmount', type: 'uint256' },
      { internalType: 'uint256', name: 'pendingWithdrawAmount', type: 'uint256' }
    ],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [],
    name: 'withdrawPaused',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  },
  { stateMutability: 'payable', type: 'receive' }
];
export const useStakeContract = () => {
  return useContract(StakeContractAddress, abi as Abi);
};
