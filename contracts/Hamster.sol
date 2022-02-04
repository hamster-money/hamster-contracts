// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "./lib/SafeMath8.sol";
import "./owner/Operator.sol";
import "./interfaces/IOracle.sol";


contract Hamster is ERC20Burnable, Operator {
    using SafeMath for uint256;
    using SafeMath8 for uint8;

    bool public rewardPoolDistributed = false;
    address public hamsterOracle;
    address public taxOffice;
    uint256 public taxRate;
    uint256 public burnThreshold = 1.10e18;
    address public taxCollectorAddress;
    bool public autoCalculateTax;
    uint256[] public taxTiersTwaps = [
        0,
        5e17,
        6e17,
        7e17,
        8e17,
        9e17,
        9.5e17,
        1e18,
        1.05e18,
        1.10e18,
        1.20e18,
        1.30e18,
        1.40e18,
        1.50e18
    ];
    uint256[] public taxTiersRates = [
        2000,
        1900,
        1800,
        1700,
        1600,
        1500,
        1500,
        1500,
        1500,
        1400,
        900,
        400,
        200,
        100
    ];
    mapping(address => bool) public excludedAddresses;

    function isAddressExcluded(address _address) external view returns (bool) {
        return excludedAddresses[_address];
    }

    function getTaxTiersTwapsCount() public view returns (uint256 count) {
        return taxTiersTwaps.length;
    }

    function getTaxTiersRatesCount() public view returns (uint256 count) {
        return taxTiersRates.length;
    }

    function _getHamsterPrice() internal view returns (uint256 _hamsterPrice) {
        try IOracle(hamsterOracle).consult(address(this), 1e18) returns (uint144 _price) {
            return uint256(_price);
        } catch {
            revert("Hamster: failed to fetch HAMSTER price from Oracle");
        }
    }

    event TaxOfficeTransferred(address oldAddress, address newAddress);

    constructor(
        uint256 _taxRate,
        address _taxCollectorAddress,
        uint256 _initialMint
    ) public ERC20("HAM", "HAM") {
        require(_taxRate < 10000, "tax equal or bigger to 100%");
        require(_taxCollectorAddress != address(0), "tax collector address must be non-zero address");
        require(_initialMint > 0, "Hamster: initial mint is zero");
        excludeAddress(address(this));
        _mint(msg.sender, _initialMint);
        taxRate = _taxRate;
        taxCollectorAddress = _taxCollectorAddress;
    }

    function disableAutoCalculateTax() external onlyTaxOffice {
        autoCalculateTax = false;
    }

    function distributeReward(
        address _genesisPool,
        uint256 _genesisPoolDistribution,
        address _hamsterPool,
        uint256 _hamsterPoolDistribution,
        address _airdropWallet,
        uint256 _airdropDistribution
    ) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_genesisPool != address(0), "!_genesisPool");
        require(_hamsterPool != address(0), "!_hamsterPool");
        require(_airdropWallet != address(0), "!_airdropWallet");
        rewardPoolDistributed = true;
        _mint(_genesisPool, _genesisPoolDistribution);
        _mint(_hamsterPool, _hamsterPoolDistribution);
        _mint(_airdropWallet, _airdropDistribution);
    }

    function enableAutoCalculateTax() external onlyTaxOffice {
        autoCalculateTax = true;
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }

    function includeAddress(address _address) external onlyOperatorOrTaxOffice returns (bool) {
        require(excludedAddresses[_address], "address can't be included");
        excludedAddresses[_address] = false;
        return true;
    }

    function mint(address recipient_, uint256 amount_) external onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter > balanceBefore;
    }

    function setBurnThreshold(uint256 _burnThreshold) external onlyTaxOffice returns (bool) {
        burnThreshold = _burnThreshold;
        return true;
    }

    function setHamsterOracle(address _hamsterOracle) external onlyOperatorOrTaxOffice {
        require(_hamsterOracle != address(0), "oracle address cannot be 0 address");
        hamsterOracle = _hamsterOracle;
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) external onlyTaxOffice {
        require(_taxCollectorAddress != address(0), "tax collector address must be non-zero address");
        taxCollectorAddress = _taxCollectorAddress;
    }

    function setTaxOffice(address _taxOffice) external onlyOperatorOrTaxOffice {
        require(_taxOffice != address(0), "tax office address cannot be 0 address");
        emit TaxOfficeTransferred(taxOffice, _taxOffice);
        taxOffice = _taxOffice;
    }

    function setTaxRate(uint256 _taxRate) external onlyTaxOffice {
        require(!autoCalculateTax, "auto calculate tax cannot be enabled");
        require(_taxRate < 10000, "tax equal or bigger to 100%");
        taxRate = _taxRate;
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) external onlyTaxOffice returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < getTaxTiersRatesCount(), "Index has to lower than count of tax tiers");
        taxTiersRates[_index] = _value;
        return true;
    }

    function setTaxTiersTwap(uint8 _index, uint256 _value) external onlyTaxOffice returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < getTaxTiersTwapsCount(), "Index has to lower than count of tax tiers");
        if (_index > 0) {
            require(_value > taxTiersTwaps[_index - 1]);
        }
        if (_index < getTaxTiersTwapsCount().sub(1)) {
            require(_value < taxTiersTwaps[_index + 1]);
        }
        taxTiersTwaps[_index] = _value;
        return true;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

    function excludeAddress(address _address) public onlyOperatorOrTaxOffice returns (bool) {
        require(!excludedAddresses[_address], "address can't be excluded");
        excludedAddresses[_address] = true;
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentTaxRate = 0;
        bool burnTax = false;
        if (autoCalculateTax) {
            uint256 currentHamsterPrice = _getHamsterPrice();
            currentTaxRate = _updateTaxRate(currentHamsterPrice);
            if (currentHamsterPrice < burnThreshold) {
                burnTax = true;
            }
        }
        if (currentTaxRate == 0 || excludedAddresses[sender]) {
            _transfer(sender, recipient, amount);
        } else {
            _transferWithTax(sender, recipient, amount, burnTax);
        }
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()).sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _transferWithTax(
        address sender,
        address recipient,
        uint256 amount,
        bool burnTax
    ) internal returns (bool) {
        uint256 taxAmount = amount.mul(taxRate).div(10000);
        uint256 amountAfterTax = amount.sub(taxAmount);
        if (burnTax) {
            super.burnFrom(sender, taxAmount);
        } else {
            _transfer(sender, taxCollectorAddress, taxAmount);
        }
        _transfer(sender, recipient, amountAfterTax);
        return true;
    }

    function _updateTaxRate(uint256 _hamsterPrice) internal returns (uint256){
        if (autoCalculateTax) {
            for (uint8 tierId = uint8(getTaxTiersTwapsCount()).sub(1); tierId >= 0; --tierId) {
                if (_hamsterPrice >= taxTiersTwaps[tierId]) {
                    require(taxTiersRates[tierId] < 10000, "tax equal or bigger to 100%");
                    taxRate = taxTiersRates[tierId];
                    return taxTiersRates[tierId];
                }
            }
        }
    }

    modifier onlyTaxOffice() {
        require(taxOffice == msg.sender, "Caller is not the tax office");
        _;
    }

    modifier onlyOperatorOrTaxOffice() {
        require(isOperator() || taxOffice == msg.sender, "Caller is not the operator or the tax office");
        _;
    }
}
