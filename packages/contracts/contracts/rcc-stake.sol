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
 * - 质押池的创建
 * - 质押池的质押
 * - 质押池的赎回
 * - 质押池的奖励
 * - 质押池的奖励的发放
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
        address stTokenAddress /** 质押池的代币地址 */;
        uint256 poolWeight /** 质押池的权重 */;
        uint256 lastRewardBlock /** 上次奖励发放的区块高度 */;
        uint256 accRCCPerST /** 每个质押代币的累计 RCC 奖励 */;
        uint256 minDepositAmount /** 最小质押金额 */;
        uint256 unStakeLockedBlocks /** 解除质押的锁定区块数 */;
    }
    struct UnstakeRequest {
        // Request withdraw amount
        uint256 amount;
        // The blocks when the request withdraw amount can be released
        uint256 unlockBlocks;
    }
    struct User {
        uint256 stAmount;
        uint256 finishedRCC;
        uint256 pendingRCC;
        UnstakeRequest[] requests;
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
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );
    // TODO:  UpdatePoolInfo 和  UpdatePool为啥要分两个？
    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unstakeLockedBlocks
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
     */

    function initialize(
        IERC20 _RCC,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _rccPerBlock
    ) public initializer {
        /** TODO:  initializer 是保留的关键字？ */
        require(
            _startBlock <= _endBlock,
            "start block must be less than end block"
        );
        require(_rccPerBlock > 0, "rcc per block must be greater than 0");

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
            _startBlock <= _endBlock,
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
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks,
        bool _withUpdate
    ) public onlyRole(ADMIN_ROLE) {
        // Default the first pool to be ETH pool, so the first pool must be added with stTokenAddress = address(0x0)
        if (pool.length > 0) {
            require(
                pool[0].stTokenAddress == address(0x0),
                "the first pool must be ETH pool"
            );
        } else {
            require(
                _stTokenAddress == address(0x0),
                "the first pool must be ETH pool"
            );
        }
        // allow the min deposit amount equal to 0
        //require(_minDepositAmount > 0, "invalid min deposit amount");
        require(_unstakeLockedBlocks > 0, "invalid withdraw locked blocks");
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
                stTokenAddress: _stTokenAddress,
                poolWeight: _poolWeight,
                lastRewardBlock: lastRewardBlock,
                accRCCPerST: 0,
                stTokenAmount: 0,
                minDepositAmount: _minDepositAmount,
                unStakeLockedBlocks: _unstakeLockedBlocks
            })
        );
        emit AddPool(
            _stTokenAddress,
            _poolWeight,
            lastRewardBlock,
            _minDepositAmount,
            _unstakeLockedBlocks
        );
    }

    /**
     * @notice Update the given pool's info (minDepositAmount and unstakeLockedBlocks). Can only be called by admin.
     */
    function updatePool(
        uint256 _poolId,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) public checkPid(_poolId) onlyRole(ADMIN_ROLE) {
        require(_poolId < pool.length, "invalid pool id");
        pool[_poolId].minDepositAmount = _minDepositAmount;
        pool[_poolId].unstakeLockedBlocks = _unstakeLockedBlocks;
        emit UpdatePoolInfo(_poolId, _minDepositAmount, _unstakeLockedBlocks);
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
        return pendingRCCByBlockNumber(_pid, _user, block.number);
    }

    /**
     * @notice Get pending RCC amount of user by block number in pool
     */
    function pendingRCCByBlockNumber(
        uint256 _poolId,
        address _user,
        uint256 _blockNumber
    ) external view returns (uint256) {
        Pool storage pool_ = pool[_poolId];
        User storage user_ = users[_poolId][_user];
        uint256 accRCCPerST = pool_.accRCCPerST;
        uint256 stSupply = pool_.stTokenAmount;
        if (_blockNumber < pool_.lastRewardBlock && stSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool_.lastRewardBlock,
                _blockNumber
            );
            uint256 rccForPool = (multiplier * pool_.poolWeight) /
                totalPoolWeight;
            accRCCPerST = accRCCPerST + (rccForPool * (1 ether)) / stSupply;
        }
        return
            user_.stAmount +
            accRCCPerST /
            (1 ether) -
            user_.finishedRCC +
            user_.pendingRCC;
    }

    /**
     * @notice Get the staking amount of user
     */
    function stakingBalance(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return users[_pid][_user].stAmount;
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
        User storage user_ = users[_poolId][_user];
        for (uint256 i = 0; i < user_.requests.length; i++) {
            if (user_.requests[i].unlockBlocks <= block.number) {
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
     */
    function updatePool(uint256 _poolId) public checkPid(_poolId) {
        Pool storage pool_ = pool[_poolId];
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }
        (bool success1, uint256 totalRCC) = getMultiplier(
            pool_.lastRewardBlock,
            block.number
        ).tryMul(pool_.poolWeight);
        require(success1, "multiplier overflow");

        uint256 stSupply = pool_.stTokenAmount;
        if (stSupply > 0) {
            (bool success2, uint256 totalRCC_) = totalRCC.tryMul(1 ether);
            require(success2, "totalRCC overflow");

            (success2, totalRCC_) = totalRCC_.tryDiv(stSupply);
            require(success2, "totalRCC overflow");

            (bool success3, uint256 accRCCPerST) = totalRCC_.tryAdd(
                pool_.poolWeight
            );
            require(success3, "totalRCC overflow");
            pool_.accRCCPerST = accRCCPerST;
        }
        pool_.lastRewardBlock = block.number;
        emit UpdatePool(_poolId, pool_.lastRewardBlock, pool_.accRCCPerST);
    }
}
