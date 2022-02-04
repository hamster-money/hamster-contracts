// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./owner/Operator.sol";
import "./interfaces/ITaxable.sol";
import "./interfaces/IUniswapV2Router.sol";


contract TaxOfficeV2 is Operator {
    using SafeMath for uint256;

    address public hamster;
    address public router;
    mapping(address => bool) public taxExclusionEnabled;

    function taxRate() external view returns (uint256) {
        return ITaxable(hamster).taxRate();
    }

    constructor(address _hamster, address _router) public {
        require(_hamster != address(0), "hamster address cannot be 0");
        require(_router != address(0), "router address cannot be 0");
        hamster = _hamster;
        router = _router;
    }

    function addLiquidityETHTaxFree(
        uint256 amtHamster,
        uint256 amtHamsterMin,
        uint256 amtFtmMin
    )
        external
        payable
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtHamster != 0 && msg.value != 0, "amounts can't be 0");
        uint256 resultAmtHamster;
        uint256 resultAmtFtm;
        uint256 liquidity;
        _excludeAddressFromTax(msg.sender);
        IERC20(hamster).transferFrom(msg.sender, address(this), amtHamster);
        _approveTokenIfNeeded(hamster, router);
        _includeAddressInTax(msg.sender);
        (resultAmtHamster, resultAmtFtm, liquidity) = IUniswapV2Router(router).addLiquidityETH{value: msg.value}(
            hamster,
            amtHamster,
            amtHamsterMin,
            amtFtmMin,
            msg.sender,
            block.timestamp
        );
        if (amtHamster.sub(resultAmtHamster) > 0) {
            IERC20(hamster).transfer(msg.sender, amtHamster.sub(resultAmtHamster));
        }
        return (resultAmtHamster, resultAmtFtm, liquidity);
    }

    function addLiquidityTaxFree(
        address token,
        uint256 amtHamster,
        uint256 amtToken,
        uint256 amtHamsterMin,
        uint256 amtTokenMin
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtHamster != 0 && amtToken != 0, "amounts can't be 0");
        uint256 resultAmtHamster;
        uint256 resultAmtToken;
        uint256 liquidity;
        _excludeAddressFromTax(msg.sender);
        IERC20(hamster).transferFrom(msg.sender, address(this), amtHamster);
        IERC20(token).transferFrom(msg.sender, address(this), amtToken);
        _approveTokenIfNeeded(hamster, router);
        _approveTokenIfNeeded(token, router);
        _includeAddressInTax(msg.sender);
        (resultAmtHamster, resultAmtToken, liquidity) = IUniswapV2Router(router).addLiquidity(
            hamster,
            token,
            amtHamster,
            amtToken,
            amtHamsterMin,
            amtTokenMin,
            msg.sender,
            block.timestamp
        );
        if (amtHamster.sub(resultAmtHamster) > 0) {
            IERC20(hamster).transfer(msg.sender, amtHamster.sub(resultAmtHamster));
        }
        if (amtToken.sub(resultAmtToken) > 0) {
            IERC20(token).transfer(msg.sender, amtToken.sub(resultAmtToken));
        }
        return (resultAmtHamster, resultAmtToken, liquidity);
    }

    function disableAutoCalculateTax() external onlyOperator {
        ITaxable(hamster).disableAutoCalculateTax();
    }

    function enableAutoCalculateTax() external onlyOperator {
        ITaxable(hamster).enableAutoCalculateTax();
    }

    function excludeAddressFromTax(address _address) external onlyOperator returns (bool) {
        return _excludeAddressFromTax(_address);
    }

    function includeAddressInTax(address _address) external onlyOperator returns (bool) {
        return _includeAddressInTax(_address);
    }

    function setBurnThreshold(uint256 _burnThreshold) external onlyOperator {
        ITaxable(hamster).setBurnThreshold(_burnThreshold);
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) external onlyOperator {
        ITaxable(hamster).setTaxCollectorAddress(_taxCollectorAddress);
    }

    function setTaxExclusionForAddress(address _address, bool _excluded) external onlyOperator {
        taxExclusionEnabled[_address] = _excluded;
    }

    function setTaxRate(uint256 _taxRate) external onlyOperator {
        ITaxable(hamster).setTaxRate(_taxRate);
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) external onlyOperator returns (bool) {
        return ITaxable(hamster).setTaxTiersRate(_index, _value);
    }

    function setTaxTiersTwap(uint8 _index, uint256 _value) external onlyOperator returns (bool) {
        return ITaxable(hamster).setTaxTiersTwap(_index, _value);
    }

    function setTaxableHamsterOracle(address _hamsterOracle) external onlyOperator {
        ITaxable(hamster).setHamsterOracle(_hamsterOracle);
    }

    function taxFreeTransferFrom(
        address _sender,
        address _recipient,
        uint256 _amt
    ) external {
        require(taxExclusionEnabled[msg.sender], "Address not approved for tax free transfers");
        _excludeAddressFromTax(_sender);
        IERC20(hamster).transferFrom(_sender, _recipient, _amt);
        _includeAddressInTax(_sender);
    }

    function transferTaxOffice(address _newTaxOffice) external onlyOperator {
        ITaxable(hamster).setTaxOffice(_newTaxOffice);
    }

    function _approveTokenIfNeeded(address _token, address _router) private {
        if (IERC20(_token).allowance(address(this), _router) == 0) {
            IERC20(_token).approve(_router, type(uint256).max);
        }
    }

    function _excludeAddressFromTax(address _address) private returns (bool) {
        if (!ITaxable(hamster).isAddressExcluded(_address)) {
            return ITaxable(hamster).excludeAddress(_address);
        }
    }

    function _includeAddressInTax(address _address) private returns (bool) {
        if (ITaxable(hamster).isAddressExcluded(_address)) {
            return ITaxable(hamster).includeAddress(_address);
        }
    }
}
