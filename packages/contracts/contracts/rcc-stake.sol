// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * 功能需求
 *
 * 质押池
 * - 质押池
 *  - 创建
 *  - 更新
 *  - 暂停质押、暂停提取
 *  - 发放奖励
 * - 普通用户
 */

// TODO: 看看这几个类型都是干啥的，需要用上翻译插件
contract RCCStake is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    // ************************************** INVARIANT **************************************

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_manager_role");
    uint256 public constant ETH_PID = 0;

    // ************************************** DATA STRUCTURE **************************************

    struct Pool {
        address stakeTokenAddress /** 质押池的代币地址 */;
        uint256 poolWeight /** 质押池的权重 */;
        uint256 lastRewardBlock /** 上次奖励发放的区块高度 */;
        uint256 accumulateRewardsPerStake /** 累计发放的奖励 / 每单位质押代币 */;
        uint256 stakeTokenAmount /**质押的总代币数量 */;
        uint256 minDepositAmount /** 最小质押金额 */;
        uint256 unStakeLockedBlocks /** 已解除质押锁定区块数 */;
    }
    struct UnStakeRequest {
        // Request withdraw amount
        uint256 amount;
        // The blocks when the request withdraw amount can be released，发起解除质押请求时，已解锁的区块数量
        uint256 unlockBlocksCounts;
    }
    struct User {
        uint256 stakeAmount;
        uint256 finishedRewards;
        uint256 pendingRewards;
        UnStakeRequest[] requests;
    }

    // ************************************** STATE VARIABLES **************************************
    // First block that RCCStake will start from
    uint256 public startBlock;
    // First block that RCCStake will end from
    uint256 public endBlock;
    // RCC token reward per block
    uint256 public rccPerBlock;
    // Pause the withdraw function
    bool public withdrawPaused;
    // Pause the claim function
    bool public claimPaused;
    // RCC token
    IERC20 public RCC;

    // Total pool weight / Sum of all pool weights
    uint256 public totalPoolWeight;

    Pool[] public pool;

    // User data
    mapping(address => User) public users;
    // ---------------- 状态变量 ----------------
    uint256 public unstakeReleaseBlocks;

    IERC20 public stToken;
    Pool[] public pools;
    // pool id => user address => user info
    mapping(uint256 => mapping(address => User)) public user;

    // ************************************** EVENT **************************************
    event SetRCC(IERC20 indexed RCC);
    event PausedWithdraw();
    event UnpausedWithdraw();
    event PausedClaim();
    event UnpausedClaim();
    event SetStartBlock(uint256 indexed startBlock);
    event SetEndBlock(uint256 indexed endBlock);
    event SetRCCPerBlock(uint256 indexed rccPerBlock);
    event AddPool(
        address indexed stakeTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unStakeLockedBlocks
    );
    // TODO:  UpdatePoolInfo 和  UpdatePool为啥要分两个？
    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unStakeLockedBlocks
    );
    event SetPoolWeight(
        uint256 indexed poolId,
        uint256 poolWeight,
        uint256 totalPoolWeight
    );
    event UpdatePool(
        uint256 indexed poolId,
        uint256 indexed lastRewardBlock,
        uint256 totalRCC
    );
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event RequestUnstake(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 indexed blockNumber
    );
    event Claim(
        address indexed user,
        uint256 indexed poolId,
        uint256 RccReward
    );

    event Stake(address indexed user, address indexed pid, uint256 amount);
    event UnStake(address indexed user, address indexed pid, uint256 amount);
    event GetRewards(address indexed user, address indexed pid, uint256 amount);

    // ************************************** MODIFIER **************************************

    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }
    modifier whenNotClaimPaused() {
        require(!claimPaused, "claim is paused");
        _;
    }
    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "withdraw is paused");
        _;
    }

    // ************************************** FUNCTIONS **************************************
    /**
     * @notice Set RCC token address. Set basic info when deploying.
     * - 执行初始化动作
     * - 设置角色权限
     * - 设置代币奖励相关信息
     */

    function initialize(
        IERC20 _RCC,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rccPerBlock
    ) public initializer {
        require(
            _startBlock <= _endBlock,
            "start block must be less than end block"
        );
        require(_rccPerBlock > 0, "rcc per block must be greater than 0");
        // TODO: 看代码，下面一行代码啥也没干呀
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        setRCC(_RCC);
        startBlock = _startBlock;
        endBlock = _endBlock;
        rccPerBlock = _rccPerBlock;
    }

    // TODO: 这个函数在这里什么意思？又没有调用的地方
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADE_ROLE) {}

    // ************************************** ADMIN FUNCTIONS **************************************
    /**
     * @notice Set RCC token address. Can only be called by admin
     */

    function setRCC(IERC20 _RCC) public onlyRole(ADMIN_ROLE) {
        RCC = _RCC;
        emit SetRCC(RCC);
    }

    /**
     * @notice Pause withdraw. Can only be called by admin.
     */
    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "withdraw has already been unpaused");
        withdrawPaused = true;
        emit PausedWithdraw();
    }

    /**
     * @notice Unpause withdraw. Can only be called by admin.
     */
    function unpPauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "withdraw has already been paused");
        withdrawPaused = false;
        emit UnpausedWithdraw();
    }

    /**
     * @notice Pause claim. Can only be called by admin.
     */
    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "claim has already been unpaused");
        claimPaused = true;
        emit PausedClaim();
    }

    /**
     * @notice Pause unpauseClaim. Can only be called by admin.
     */
    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "claim has already been unpaused");
        claimPaused = false;
        emit UnpausedClaim();
    }

    // TODO: 这俩函数为啥单独拎出来，设置区块的放一类，设置池子放另一类？
    /**
     * @notice Update staking start block. Can only be called by admin.
     */
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE) {
        require(
            _startBlock <= endBlock,
            "start block must be less than end block"
        );
        startBlock = _startBlock;
        emit SetStartBlock(_startBlock);
    }

    /**
     * @notice Update staking end block. Can only be called by admin.
     */
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE) {
        require(
            startBlock <= _endBlock,
            "start block must be less than end block"
        );
        endBlock = _endBlock;
        emit SetEndBlock(_endBlock);
    }

    /**
     * @notice Update the RCC reward amount per block. Can only be called by admin.
     */
    function setRCCPerBlock(uint256 _rccPerBlock) public onlyRole(ADMIN_ROLE) {
        require(_rccPerBlock > 0, "rcc per block must be greater than 0");
        rccPerBlock = _rccPerBlock;
        emit SetRCCPerBlock(_rccPerBlock);
    }

    /**
     * @notice Add a new staking to pool. Can only be called by admin
     * DO NOT add the same staking token more than once. RCC rewards will be messed up if you do
     */
    function addPool(
        address _stakeTokenAddress,
        uint256 _poolWeight /** TODO: 这权重放的是不是太随意了？ */,
        uint256 _minDepositAmount,
        uint256 _unStakeLockedBlocks,
        bool _withUpdate /** 是指创建这个池子的同时要不要同时更新别的池子（因为权重有了变化） */
    ) public onlyRole(ADMIN_ROLE) {
        // Default the first pool to be ETH pool, so the first pool must be added with stakeTokenAddress = address(0x0)
        if (pool.length > 0) {
            require(
                pool[0].stakeTokenAddress == address(0x0),
                "the first pool must be ETH pool"
            );
        } else {
            require(
                _stakeTokenAddress == address(0x0),
                "the first pool must be ETH pool"
            );
        }
        // allow the min deposit amount equal to 0 TODO: 为啥？存款0有什么意义？
        require(_unStakeLockedBlocks > 0, "invalid withdraw locked blocks"); // TODO: 这个等于0也可以吧？
        require(block.number < endBlock, "already ended");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalPoolWeight += _poolWeight;
        pool.push(
            Pool({
                stakeTokenAddress: _stakeTokenAddress,
                poolWeight: _poolWeight,
                lastRewardBlock: lastRewardBlock,
                accumulateRewardsPerStake: 0,
                stakeTokenAmount: 0,
                minDepositAmount: _minDepositAmount,
                unStakeLockedBlocks: _unStakeLockedBlocks
            })
        );
        emit AddPool(
            _stakeTokenAddress,
            _poolWeight,
            lastRewardBlock,
            _minDepositAmount,
            _unStakeLockedBlocks
        );
    }

    /**
     * @notice Update the given pool's info (minDepositAmount and unStakeLockedBlocks). Can only be called by admin.
     * 这就是函数签名的作用，函数重名没事儿，还有参数返回值啥的呢；
     */
    function updatePool(
        uint256 _poolId,
        uint256 _minDepositAmount,
        uint256 _unStakeLockedBlocks
    ) public checkPid(_poolId) onlyRole(ADMIN_ROLE) {
        require(_poolId < pool.length, "invalid pool id");
        pool[_poolId].minDepositAmount = _minDepositAmount;
        pool[_poolId].unStakeLockedBlocks = _unStakeLockedBlocks;
        emit UpdatePoolInfo(_poolId, _minDepositAmount, _unStakeLockedBlocks);
    }

    /**
     * @notice Update the given pool's weight. Can only be called by admin.
     */
    function setPoolWeight(
        uint256 _poolId,
        uint256 _poolWeight,
        bool _withUpdate
    ) public onlyRole(ADMIN_ROLE) {
        require(_poolId < pool.length, "invalid pool id");
        require(_poolWeight > 0, "invalid pool weight");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalPoolWeight =
            totalPoolWeight -
            pool[_poolId].poolWeight +
            _poolWeight;
        pool[_poolId].poolWeight = _poolWeight;
        emit SetPoolWeight(_poolId, _poolWeight, totalPoolWeight);
    }

    // ************************************** QUERY FUNCTION **************************************
    /**
     * @notice Get the length/amount of pool
     */
    function getPoolLength() public view returns (uint256) {
        return pool.length;
    }

    /**
     * @notice Return reward multiplier over given _from to _to block. [_from, _to)
     *
     * @param _from    From block number (included)
     * @param _to      To block number (exluded)
     */
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 multiplier) {
        require(_from <= _to, "invalid range");
        if (_from < startBlock) {
            _from = startBlock;
        }
        if (_to > endBlock) {
            _to = endBlock;
        }
        require(_to - _from > 0, "invalid range");
        bool success;
        (success, multiplier) = (_to - _from).tryMul(rccPerBlock);
        require(success, "multiplier overflow");
    }

    /**
     * @notice Get pending RCC amount of user in pool
     */
    function getPendingRCC(
        uint256 _poolId,
        address _user
    ) external view checkPid(_poolId) returns (uint256) {
        return pendingRCCByBlockNumber(_poolId, _user, block.number);
    }

    /**
     * @notice Get pending RCC amount of user by block number in pool
     */
    function pendingRCCByBlockNumber(
        uint256 _poolId,
        address _user,
        uint256 _blockNumber
    ) public view returns (uint256) {
        Pool storage pool_ = pool[_poolId];
        User storage user_ = user[_poolId][_user];
        uint256 accumulateRewardsPerStake = pool_.accumulateRewardsPerStake;
        uint256 stSupply = pool_.stakeTokenAmount;
        if (_blockNumber < pool_.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool_.lastRewardBlock,
                _blockNumber
            );
            uint256 rccForPool = (multiplier * pool_.poolWeight) /
                totalPoolWeight;
            accumulateRewardsPerStake =
                accumulateRewardsPerStake +
                (rccForPool * (1 ether)) /
                stSupply;
        }
        return
            user_.stakeAmount +
            accumulateRewardsPerStake /
            (1 ether) -
            user_.finishedRewards +
            user_.pendingRewards;
    }

    /**
     * @notice Get the staking amount of user
     */
    function stakingBalance(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return user[_pid][_user].stakeAmount;
    }

    /**
     * @notice Get the withdraw amount info, including the locked unstake amount and the unlocked unstake amount
     */
    function withdrawAmount(
        uint256 _poolId,
        address _user
    )
        public
        view
        checkPid(_poolId)
        returns (uint256 requestAmount, uint256 pendingWithdrawAmount)
    {
        User storage user_ = user[_poolId][_user];
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocksCounts <= block.number) {
                pendingWithdrawAmount =
                    pendingWithdrawAmount +
                    user_.requests[i].amount;
            }
            requestAmount = requestAmount + user_.requests[i].amount;
        }
    }

    // ************************************** PUBLIC FUNCTION **************************************
    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     * 主要是更新
     * - 池子里每单位代币累计发放的奖励；
     * - 最后发放奖励区块的number；
     */
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];

        if (block.number <= pool_.lastRewardBlock) {
            return;
        }
        // 在这段区块里，所有池子奖励的代币总和 * 池子的权重
        (bool success1, uint256 totalRCC) = getMultiplier(
            pool_.lastRewardBlock,
            block.number
        ).tryMul(pool_.poolWeight);
        require(success1, "overflow");
        // 池子奖励的代币总和 * 池子的权重 / 池子总权重 = 该池子这段区块链奖励的代币总和;
        // 之所以要分步计算，就是避免中间某个步骤计算溢出导致错误；
        (success1, totalRCC) = totalRCC.tryDiv(totalPoolWeight);
        require(success1, "overflow");
        // 看这个池子里已质押的代币总数量
        uint256 stSupply = pool_.stakeTokenAmount;
        // 要是有质押的代币
        if (stSupply > 0) {
            // TODO: 乘个1 ether是什么意思呢？
            (bool success2, uint256 totalRCC_) = totalRCC.tryMul(1 ether);
            require(success2, "overflow");
            // 这段区块链里，每一单位代币要分的token数量
            (success2, totalRCC_) = totalRCC_.tryDiv(stSupply);
            require(success2, "overflow");
            // 累计发放的记录上
            (bool success3, uint256 accumulateRewardsPerStake) = pool_
                .accumulateRewardsPerStake
                .tryAdd(totalRCC_);
            require(success3, "overflow");
            pool_.accumulateRewardsPerStake = accumulateRewardsPerStake;
        }
        // 更新最后计算奖励的区块
        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalRCC);
    }

    /**
     * @notice Update reward variables for all pools. Be careful of gas spending!
     */
    function massUpdatePools() public {
        /** TODO: 这个为啥用public，不用private */
        uint256 length = pool.length;
        for (uint256 i = 0; i < length; i++) {
            updatePool(i);
        }
    }

    /**
     * @notice Deposit staking ETH for RCC rewards
     */
    function depositETH() public payable whenNotPaused {
        Pool storage pool_ = pool[ETH_PID];
        require(
            pool_.stakeTokenAddress == address(0x0),
            "ETH pool must be created first"
        );

        uint256 _amount = msg.value;
        require(_amount > pool_.minDepositAmount, "invalid deposit amount");
        _deposit(ETH_PID, _amount);
    }

    /**
     * @notice Deposit staking token for RCC rewards
     * Before depositing, user needs approve this contract to be able to spend or transfer their staking tokens
     *
     * @param _pid       Id of the pool to be deposited to
     * @param _amount    Amount of staking tokens to be deposited
     */
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) public whenNotWithdrawPaused checkPid(_pid) {
        // TODO: 为什么不接受ETH的质押
        require(_pid != 0, "deposit not support ETH staking");
        Pool storage pool_ = pool[_pid];
        require(_amount > pool_.minDepositAmount, "invalid deposit amount");
        if (_amount > 0) {
            IERC20(pool_.stakeTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        _deposit(_pid, _amount);
    }

    /**
     * @notice Unstake staking tokens
     *
     * @param _pid       Id of the pool to be withdrawn from
     * @param _amount    amount of staking tokens to be withdrawn
     */
    function unstake(
        uint256 _pid,
        uint256 _amount
    ) public whenNotPaused whenNotWithdrawPaused checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        require(user_.stakeAmount >= _amount, "insufficient staking amount");
        updatePool(_pid);
        uint256 pendingRCC_ = (user_.stakeAmount *
            pool_.accumulateRewardsPerStake) /
            (1 ether) -
            user_.finishedRewards;
        if (pendingRCC_ > 0) {
            user_.pendingRewards += pendingRCC_;
        }
        if (_amount > 0) {
            user_.stakeAmount -= _amount;
            user_.requests.push(
                UnStakeRequest({
                    amount: _amount,
                    unlockBlocksCounts: block.number + pool_.unStakeLockedBlocks
                })
            );
        }
        pool_.stakeTokenAmount -= _amount;
        user_.finishedRewards +=
            (user_.stakeAmount * pool_.accumulateRewardsPerStake) /
            (1 ether);
        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    /**
     * @notice Withdraw the unlock unstake amount
     * @param _pid       Id of the pool to be withdrawn from
     * 功能: 提取一个池子里所有的代币
     * - 提取池子里所有的代币；
     * - 拿走所有的奖励；
     * - 更新池子
     * - 发射事件
     *
     */
    function withdraw(
        uint256 _pid
    ) public whenNotPaused whenNotWithdrawPaused checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        uint256 pendingWithdraw_;
        uint256 popNum_;
        // 跳过解锁时间小于当前区块的请求
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocksCounts <= block.number) {
                break;
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.requests[i].amount;
            popNum_++;
        }
        // TODO: 这啥意思
        for (uint256 i = 0; i < user_.requests.length - popNum_; i++) {
            user_.requests[i] = user_.requests[i + popNum_];
        }
        for (uint256 i = 0; i < popNum_; i++) {
            user_.requests.pop();
        }
        if (pendingWithdraw_ > 0) {
            if (pool_.stakeTokenAddress == address(0x0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stakeTokenAddress).safeTransfer(
                    msg.sender,
                    pendingWithdraw_
                );
            }
        }
        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    /**
     * @notice Claim RCC tokens reward
     *
     * @param _pid       Id of the pool to be claimed from
     */
    function claim(
        uint256 _pid
    ) public whenNotPaused checkPid(_pid) whenNotClaimPaused {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        updatePool(_pid);
        uint256 pendingRCC_ = (user_.stakeAmount *
            pool_.accumulateRewardsPerStake) /
            (1 ether) -
            user_.finishedRewards +
            user_.pendingRewards;
        if (pendingRCC_ > 0) {
            user_.pendingRewards = 0;
            _safeRCCTransfer(msg.sender, pendingRCC_);
        }
        user_.finishedRewards =
            (user_.stakeAmount * pool_.accumulateRewardsPerStake) /
            (1 ether);
        emit Claim(msg.sender, _pid, pendingRCC_);
    }

    // ************************************** INTERNAL FUNCTION **************************************

    /**
     * @notice Deposit staking token for RCC rewards
     *
     * @param _pid       Id of the pool to be deposited to
     * @param _amount    Amount of staking tokens to be deposited
     */
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        updatePool(_pid);
    }

    /**
     * @notice Safe RCC transfer function, just in case if rounding error causes pool to not have enough RCCs
     *
     * @param _to        Address to get transferred RCCs
     * @param _amount    Amount of RCC to be transferred
     */
    function _safeRCCTransfer(address _to, uint256 _amount) internal {
        uint256 RCCBal = RCC.balanceOf(address(this));
        if (_amount <= RCCBal) {
            RCC.transfer(_to, _amount);
        } else {
            RCC.transfer(_to, RCCBal);
        }
    }

    /**
     * @notice Safe ETH transfer function
     *
     * @param _to        Address to get transferred ETH
     * @param _amount    Amount of ETH to be transferred
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{value: _amount}(
            ""
        );
        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "ETH transfer operation did not succeed"
            );
        }
    }
}
