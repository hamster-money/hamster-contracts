// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWFTM.sol";


contract HamsterZapper is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public hamster;
    address public hshare;
    IUniswapV2Router public router;
    address public wftm;

    constructor(
        address hamster_,
        address hshare_,
        address router_,
        address wftm_
    ) public Ownable() {
        address zero = address(0);
        require(hamster_ != zero, "HamsterZapper: Hamster is zero address");
        require(hshare_ != zero, "HamsterZapper: HShare is zero address");
        require(router_ != zero, "HamsterZapper: Router is zero address");
        require(wftm_ != zero, "HamsterZapper: Wrapped is zero address");
        router = IUniswapV2Router(router_);
        hamster = hamster_;
        hshare = hshare_;
        wftm = wftm_;
    }

    function withdraw(address token) external onlyOwner returns (bool success){
        success = true;
        if (token == address(0)) {
            msg.sender.transfer(address(this).balance);
            return success;
        }
        IERC20 token_ = IERC20(token);
        token_.safeTransfer(msg.sender, token_.balanceOf(address(this)));
    }

    function zapIn(address to) external payable returns (uint256 liquidity) {
        require(to == hamster || to == hshare, "HamsterZapper: Unsupported 'to' token");
        uint256 amountIn = msg.value;
        if (amountIn == 0) return 0;
        IWFTM(wftm).deposit{value: amountIn}();
        liquidity = _zapInFromWFTM(to);
    }

    function zapInToken(address to, address from, uint256 amount) external returns (uint256 liquidity) {
        require(to == hamster || to == hshare, "HamsterZapper: Unsupported 'to' token");
        if (amount == 0) return 0;
        IERC20(from).safeTransferFrom(msg.sender, address(this), amount);
        if (from != wftm) _swap(from, wftm, amount);
        liquidity = _zapInFromWFTM(to);
    }

    function _addLiquidity(
        address token0,
        address token1,
        uint256 amountIn0,
        uint256 amountIn1
    ) private returns (uint256 liquidity) {
        _approveIfNeeded(token0, address(router), amountIn0);
        _approveIfNeeded(token1, address(router), amountIn1);
        (,,liquidity) = router.addLiquidity(
            token0,
            token1,
            amountIn0,
            amountIn1,
            1,
            1,
            msg.sender,
            block.timestamp
        );
    }

    function _approveIfNeeded(address token, address target, uint256 amount) private {
        IERC20 token_ = IERC20(token);
        if (token_.allowance(address(this), target) < amount) token_.safeApprove(target, type(uint).max);
    }

    function _returnAssets(address[] memory tokens) private {
        address caller = msg.sender;
        address this_ = address(this);
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 balance = IERC20(token).balanceOf(this_);
            if (balance > 0) token.safeTransfer(caller, balance);
        }
    }

    function _swap(
        address from,
        address to,
        uint256 amountIn
    ) private returns (uint256 result, address[] memory path) {
        _approveIfNeeded(from, address(router), amountIn);
        path = new address[](2);
        path[0] = from;
        path[1] = to;
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            1,
            path,
            address(this),
            block.timestamp
        );
        result = amounts[amounts.length - 1];
    }

    function _zapInFromWFTM(address to) internal returns (uint256 liquidity) {
        uint256 halfAmount = IERC20(wftm).balanceOf(address(this)).div(2);
        (uint256 toAmount, address[] memory path) = _swap(wftm, to, halfAmount);
        liquidity = _addLiquidity(wftm, to, halfAmount, toAmount);
        _returnAssets(path);
    }
}
