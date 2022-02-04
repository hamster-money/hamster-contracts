// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../HShare.sol";


contract MockedHShare is HShare {
    constructor(
        uint256 _startTime,
        uint256 _initialMint,
        uint256 _vestingDuration,
        address _communityFund,
        uint256 _communityFundAllocation,
        address _devFund,
        uint256 _devFundAllocation
    ) public HShare(
        _startTime,
        _initialMint,
        _vestingDuration,
        _communityFund,
        _communityFundAllocation,
        _devFund,
        _devFundAllocation
    ) {}

    function mint(uint256 amount) external returns (bool) {
        _mint(msg.sender, amount);
        return true;
    }
}
