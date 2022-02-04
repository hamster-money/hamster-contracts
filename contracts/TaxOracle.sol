// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract TaxOracle is Ownable {
    using SafeMath for uint256;

    IERC20 public hamster;
    IERC20 public wftm;
    address public pair;

    constructor(
        address _hamster,
        address _wftm,
        address _pair
    ) public {
        require(_hamster != address(0), "hamster address cannot be 0");
        require(_wftm != address(0), "wftm address cannot be 0");
        require(_pair != address(0), "pair address cannot be 0");
        hamster = IERC20(_hamster);
        wftm = IERC20(_wftm);
        pair = _pair;
    }

    function consult(address _token, uint256 _amountIn) external view returns (uint144 amountOut) {
        require(_token == address(hamster), "token needs to be hamster");
        uint256 hamsterBalance = hamster.balanceOf(pair);
        uint256 wftmBalance = wftm.balanceOf(pair);
        return uint144(hamsterBalance.mul(_amountIn).div(wftmBalance));
    }

    function getHamsterBalance() external view returns (uint256) {
	    return hamster.balanceOf(pair);
    }

    function getWftmBalance() external view returns (uint256) {
	    return wftm.balanceOf(pair);
    }

    function getPrice() external view returns (uint256) {
        uint256 hamsterBalance = hamster.balanceOf(pair);
        uint256 wftmBalance = wftm.balanceOf(pair);
        return hamsterBalance.mul(1e18).div(wftmBalance);
    }

    function setHamster(address _hamster) external onlyOwner returns (bool) {
        require(_hamster != address(0), "hamster address cannot be 0");
        hamster = IERC20(_hamster);
        return true;
    }

    function setWftm(address _wftm) external onlyOwner returns (bool) {
        require(_wftm != address(0), "wftm address cannot be 0");
        wftm = IERC20(_wftm);
        return true;
    }

    function setPair(address _pair) external onlyOwner returns (bool) {
        require(_pair != address(0), "pair address cannot be 0");
        pair = _pair;
        return true;
    }
}
