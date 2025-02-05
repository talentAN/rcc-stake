'use client';
import { Box, TextField, Typography } from '@mui/material';
import { useStakeContract } from '../../hooks/use-contract';
import { useCallback, useEffect, useState } from 'react';
import { Pid } from '../../utils';
import { useAccount, useWalletClient } from 'wagmi';
import { formatUnits, parseUnits, zeroAddress } from 'viem';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import LoadingButton from '@mui/lab/LoadingButton';
import { toast } from 'react-toastify';
import { waitForTransactionReceipt } from 'viem/actions';

const Home = () => {
  const stakeContract = useStakeContract();
  const { address, isConnected } = useAccount();
  const [stakedAmount, setStakedAmount] = useState('0');
  const [amount, setAmount] = useState('0');
  const [loading, setLoading] = useState(false);
  const { data } = useWalletClient();

  const handleStake = async () => {
    if (!stakeContract || !data) return;
    try {
      setLoading(true);
      const tx = await stakeContract.write.depositETH([], { value: parseUnits(amount, 18) });
      const res = await waitForTransactionReceipt(data, { hash: tx });
      console.log(res, 'tx');
      toast.success('Transaction receipt !');
      setLoading(false);
      getStakedAmount();
    } catch (error) {
      setLoading(false);
      console.log(error, 'stake-error');
    }
  };

  const getStakedAmount = useCallback(async () => {
    if (address && stakeContract) {
      // const res = await stakeContract?.read.poolLength();
      const res = await stakeContract?.read.stakingBalance([Pid, address]);
      setStakedAmount(formatUnits(res as bigint, 18));
    }
  }, [stakeContract, address]);

  useEffect(() => {
    if (stakeContract && address) {
      getStakedAmount();
    }
  }, [stakeContract, address]);

  return <div>hhhhhhh</div>;

  return (
    <Box display={'flex'} flexDirection={'column'} alignItems={'center'} width={'100%'}>
      <Typography sx={{ fontSize: '30px', fontWeight: 'bold' }}>Rcc Stake</Typography>
      <Typography sx={{}}>Stake ETH to earn tokens.</Typography>
      <Box
        sx={{
          border: '1px solid #eee',
          borderRadius: '12px',
          p: '20px',
          width: '600px',
          mt: '30px'
        }}>
        <Box display={'flex'} alignItems={'center'} gap={'5px'} mb='10px'>
          <Box>Staked Amount: </Box>
          <Box>{stakedAmount} ETH</Box>
        </Box>
        <TextField
          onChange={e => {
            setAmount(e.target.value);
          }}
          sx={{ minWidth: '300px' }}
          label='Amount'
          variant='outlined'
        />
        <Box mt='30px'>
          {!isConnected ? (
            <ConnectButton />
          ) : (
            <LoadingButton variant='contained' loading={loading} onClick={handleStake}>
              Stake
            </LoadingButton>
          )}
        </Box>
      </Box>
    </Box>
  );
};

export default Home;
