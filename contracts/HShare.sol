// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./owner/Operator.sol";


contract HShare is ERC20Burnable, Operator {
    using SafeMath for uint256;

    uint256 public communityFundAllocation;
    uint256 public devFundAllocation;
    uint256 public vestingDuration;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public communityFundRewardRate;
    uint256 public devFundRewardRate;
    address public communityFund;
    address public devFund;
    uint256 public communityFundLastClaimed;
    uint256 public devFundLastClaimed;
    bool public rewardPoolDistributed = false;

    function unclaimedDevFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (devFundLastClaimed >= _now) return 0;
        _pending = _now.sub(devFundLastClaimed).mul(devFundRewardRate);
    }

    function unclaimedTreasuryFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > endTime) _now = endTime;
        if (communityFundLastClaimed >= _now) return 0;
        _pending = _now.sub(communityFundLastClaimed).mul(communityFundRewardRate);
    }

    constructor(
        uint256 _startTime,
        uint256 _initialMint,
        uint256 _vestingDuration,
        address _communityFund,
        uint256 _communityFundAllocation,
        address _devFund,
        uint256 _devFundAllocation
    ) public ERC20("HSHARE", "HSHARE") {
        require(_initialMint > 0, "Hamster: initial mint is zero");
        _mint(msg.sender, _initialMint);
        startTime = _startTime;
        vestingDuration = _vestingDuration;
        endTime = startTime + vestingDuration;
        communityFundLastClaimed = startTime;
        devFundLastClaimed = startTime;
        communityFundAllocation = _communityFundAllocation;
        devFundAllocation = _devFundAllocation;
        communityFundRewardRate = communityFundAllocation.div(vestingDuration);
        devFundRewardRate = devFundAllocation.div(vestingDuration);
        require(_devFund != address(0), "Address cannot be 0");
        require(_communityFund != address(0), "Address cannot be 0");
        devFund = _devFund;
        communityFund = _communityFund;
    }

    function claimRewards() external {
        uint256 _pending = unclaimedTreasuryFund();
        if (_pending > 0 && communityFund != address(0)) {
            _mint(communityFund, _pending);
            communityFundLastClaimed = block.timestamp;
        }
        _pending = unclaimedDevFund();
        if (_pending > 0 && devFund != address(0)) {
            _mint(devFund, _pending);
            devFundLastClaimed = block.timestamp;
        }
    }

    function distributeReward(address _farmingIncentiveFund, uint256 _farmingPoolAllocation) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_farmingIncentiveFund != address(0), "!_farmingIncentiveFund");
        rewardPoolDistributed = true;
        _mint(_farmingIncentiveFund, _farmingPoolAllocation);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }

    function setDevFund(address _devFund) external {
        require(msg.sender == devFund, "!dev");
        require(_devFund != address(0), "zero");
        devFund = _devFund;
    }

    function setTreasuryFund(address _communityFund) external {
        require(msg.sender == devFund, "!dev");
        communityFund = _communityFund;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }
}
