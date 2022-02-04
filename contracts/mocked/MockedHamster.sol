// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../Hamster.sol";


contract MockedHamster is Hamster {
    constructor(
        uint256 _taxRate,
        address _taxCollectorAddress,
        uint256 _initialMint
    ) public Hamster(
        _taxRate,
        _taxCollectorAddress,
        _initialMint
    ) {}

    function mint(uint256 amount) external returns (bool) {
        _mint(msg.sender, amount);
        return true;
    }
}
