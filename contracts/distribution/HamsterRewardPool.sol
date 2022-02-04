// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


contract HamsterRewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 token;
        uint256 allocPoint;
        uint256 lastRewardTime;
        uint256 accHamsterPerShare;
        bool isStarted;
    }

    address public operator;
    IERC20 public hamster;
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public poolStartTime;
    uint256[2] public epochTotalRewards;
    uint256[3] public epochEndTimes;
    uint256[3] public epochHamsterPerSecond;

    function pendingHAMSTER(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accHamsterPerShare = pool.accHamsterPerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && tokenSupply != 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _hamsterReward = _generatedReward.mul(pool.allocPoint).div(totalAllocPoint);
            accHamsterPerShare = accHamsterPerShare.add(_hamsterReward.mul(1e18).div(tokenSupply));
        }
        return user.amount.mul(accHamsterPerShare).div(1e18).sub(user.rewardDebt);
    }

    function getGeneratedReward(uint256 _fromTime, uint256 _toTime) public view returns (uint256) {
        for (uint8 epochId = 2; epochId >= 1; --epochId) {
            if (_toTime >= epochEndTimes[epochId - 1]) {
                if (_fromTime >= epochEndTimes[epochId - 1]) {
                    return _toTime.sub(_fromTime).mul(epochHamsterPerSecond[epochId]);
                }
                uint256 _generatedReward = _toTime.sub(epochEndTimes[epochId - 1]).mul(epochHamsterPerSecond[epochId]);
                if (epochId == 1) {
                    return _generatedReward.add(epochEndTimes[0].sub(_fromTime).mul(epochHamsterPerSecond[0]));
                }
                for (epochId = epochId - 1; epochId >= 1; --epochId) {
                    if (_fromTime >= epochEndTimes[epochId - 1]) {
                        return _generatedReward
                            .add(epochEndTimes[epochId]
                            .sub(_fromTime)
                            .mul(epochHamsterPerSecond[epochId]));
                    }
                    _generatedReward = _generatedReward
                        .add(epochEndTimes[epochId]
                        .sub(epochEndTimes[epochId - 1])
                        .mul(epochHamsterPerSecond[epochId]));
                }
                return _generatedReward.add(epochEndTimes[0].sub(_fromTime).mul(epochHamsterPerSecond[0]));
            }
        }
        return _toTime.sub(_fromTime).mul(epochHamsterPerSecond[0]);
    }

    function checkPoolDuplicate(IERC20 _token) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].token != _token, "HamsterRewardPool: existing pool?");
        }
    }

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);

    constructor(
        address _hamster,
        uint256 _poolStartTime,
        uint256 _firstEpochAmount,
        uint256 _firstEpochDuration,
        uint256 _secondEpochAmount,
        uint256 _secondEpochDuration
    ) public {
        require(block.timestamp < _poolStartTime, "late");
        require(_hamster != address(0), "HamsterRewardPool: hamster is zero address");
        require(_firstEpochAmount > 0, "HamsterRewardPool: firstEpochAmount is zero");
        require(_firstEpochDuration > 0, "HamsterRewardPool: firstEpochDuration is zero");
        require(_secondEpochAmount > 0, "HamsterRewardPool: secondEpochAmount is zero");
        require(_secondEpochDuration > 0, "HamsterRewardPool: secondEpochDuration is zero");
        hamster = IERC20(_hamster);
        epochTotalRewards[0] = _firstEpochAmount;
        epochTotalRewards[1] = _secondEpochAmount;
        poolStartTime = _poolStartTime;
        epochEndTimes[0] = poolStartTime.add(_firstEpochDuration);
        epochEndTimes[1] = epochEndTimes[0].add(_secondEpochDuration);
        epochHamsterPerSecond[0] = epochTotalRewards[0].div(_firstEpochDuration);
        epochHamsterPerSecond[1] = epochTotalRewards[1].div(_secondEpochDuration);
        epochHamsterPerSecond[2] = 0;
        operator = msg.sender;
    }

    function add(
        uint256 _allocPoint,
        IERC20 _token,
        bool _withUpdate,
        uint256 _lastRewardTime
    ) external onlyOperator {
        checkPoolDuplicate(_token);
        if (_withUpdate) {
            massUpdatePools();
        }
        if (block.timestamp < poolStartTime) {
            if (_lastRewardTime == 0) {
                _lastRewardTime = poolStartTime;
            } else {
                if (_lastRewardTime < poolStartTime) {
                    _lastRewardTime = poolStartTime;
                }
            }
        } else {
            if (_lastRewardTime == 0 || _lastRewardTime < block.timestamp) {
                _lastRewardTime = block.timestamp;
            }
        }
        bool _isStarted = (_lastRewardTime <= poolStartTime) || (_lastRewardTime <= block.timestamp);
        poolInfo.push(PoolInfo({
            token: _token,
            allocPoint: _allocPoint,
            lastRewardTime: _lastRewardTime,
            accHamsterPerShare: 0,
            isStarted: _isStarted
        }));
        if (_isStarted) {
            totalAllocPoint = totalAllocPoint.add(_allocPoint);
        }
    }

    function deposit(uint256 _pid, uint256 _amount) external {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 _pending = user.amount.mul(pool.accHamsterPerShare).div(1e18).sub(user.rewardDebt);
            if (_pending > 0) {
                safeHamsterTransfer(_sender, _pending);
                emit RewardPaid(_sender, _pending);
            }
        }
        if (_amount > 0) {
            pool.token.safeTransferFrom(_sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accHamsterPerShare).div(1e18);
        emit Deposit(_sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.token.safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 amount,
        address to
    ) external onlyOperator {
        if (block.timestamp < epochEndTimes[1] + 30 days) {
            require(_token != hamster, "!hamster");
            uint256 length = poolInfo.length;
            for (uint256 pid = 0; pid < length; ++pid) {
                PoolInfo storage pool = poolInfo[pid];
                require(_token != pool.token, "!pool.token");
            }
        }
        _token.safeTransfer(to, amount);
    }

    function set(uint256 _pid, uint256 _allocPoint) external onlyOperator {
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        if (pool.isStarted) {
            totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(_allocPoint);
        }
        pool.allocPoint = _allocPoint;
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function withdraw(uint256 _pid, uint256 _amount) external {
        address _sender = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 _pending = user.amount.mul(pool.accHamsterPerShare).div(1e18).sub(user.rewardDebt);
        if (_pending > 0) {
            safeHamsterTransfer(_sender, _pending);
            emit RewardPaid(_sender, _pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.token.safeTransfer(_sender, _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accHamsterPerShare).div(1e18);
        emit Withdraw(_sender, _pid, _amount);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        if (!pool.isStarted) {
            pool.isStarted = true;
            totalAllocPoint = totalAllocPoint.add(pool.allocPoint);
        }
        if (totalAllocPoint > 0) {
            uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
            uint256 _hamsterReward = _generatedReward.mul(pool.allocPoint).div(totalAllocPoint);
            pool.accHamsterPerShare = pool.accHamsterPerShare.add(_hamsterReward.mul(1e18).div(tokenSupply));
        }
        pool.lastRewardTime = block.timestamp;
    }

    function safeHamsterTransfer(address _to, uint256 _amount) internal {
        uint256 _hamsterBal = hamster.balanceOf(address(this));
        if (_hamsterBal > 0) {
            if (_amount > _hamsterBal) {
                hamster.safeTransfer(_to, _hamsterBal);
            } else {
                hamster.safeTransfer(_to, _amount);
            }
        }
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "HamsterRewardPool: caller is not the operator");
        _;
    }
}
