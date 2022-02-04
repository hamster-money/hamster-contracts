// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./owner/Operator.sol";
import "./utils/ContractGuard.sol";
import "./interfaces/IBasisAsset.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IHamsterWheel.sol";


contract Treasury is ContractGuard {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    uint256 public constant PERIOD = 6 hours;
    address public operator;
    bool public initialized = false;
    uint256 public startTime;
    uint256 public epoch = 0;
    uint256 public epochSupplyContractionLeft = 0;
    address[] public excludedFromTotalSupply;
    address public hamster;
    address public hamsterbond;
    address public hamstershare;
    address public hamsterWheel;
    address public hamsterOracle;
    uint256 public hamsterPriceOne;
    uint256 public hamsterPriceCeiling;
    uint256 public seigniorageSaved;
    uint256[] public supplyTiers;
    uint256[] public maxExpansionTiers;
    uint256 public maxSupplyExpansionPercent;
    uint256 public bondDepletionFloorPercent;
    uint256 public seigniorageExpansionFloorPercent;
    uint256 public maxSupplyContractionPercent;
    uint256 public maxDebtRatioPercent;
    uint256 public bootstrapEpochs;
    uint256 public bootstrapSupplyExpansionPercent;
    uint256 public previousEpochHamsterPrice;
    uint256 public maxDiscountRate;
    uint256 public maxPremiumRate;
    uint256 public discountPercent;
    uint256 public premiumThreshold;
    uint256 public premiumPercent;
    uint256 public mintingFactorForPayingDebt;
    address public daoFund;
    uint256 public daoFundSharedPercent;
    address public devFund;
    uint256 public devFundSharedPercent;

    function getBurnableHamsterLeft() external view returns (uint256 _burnableHamsterLeft) {
        uint256 _hamsterPrice = getHamsterPrice();
        if (_hamsterPrice <= hamsterPriceOne) {
            uint256 _hamsterSupply = getHamsterCirculatingSupply();
            uint256 _bondMaxSupply = _hamsterSupply.mul(maxDebtRatioPercent).div(10000);
            uint256 _bondSupply = IERC20(hamsterbond).totalSupply();
            if (_bondMaxSupply > _bondSupply) {
                uint256 _maxMintableBond = _bondMaxSupply.sub(_bondSupply);
                uint256 _maxBurnableHamster = _maxMintableBond.mul(_hamsterPrice).div(1e18);
                _burnableHamsterLeft = Math.min(epochSupplyContractionLeft, _maxBurnableHamster);
            }
        }
    }

    function getHamsterUpdatedPrice() external view returns (uint256 _hamsterPrice) {
        try IOracle(hamsterOracle).twap(hamster, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult HAMSTER price from the oracle");
        }
    }

    function getRedeemableBonds() external view returns (uint256 _redeemableBonds) {
        uint256 _hamsterPrice = getHamsterPrice();
        if (_hamsterPrice > hamsterPriceCeiling) {
            uint256 _totalHamster = IERC20(hamster).balanceOf(address(this));
            uint256 _rate = getBondPremiumRate();
            if (_rate > 0) {
                _redeemableBonds = _totalHamster.mul(1e18).div(_rate);
            }
        }
    }

    function getReserve() external view returns (uint256) {
        return seigniorageSaved;
    }

    function isInitialized() external view returns (bool) {
        return initialized;
    }

    function getBondDiscountRate() public view returns (uint256 _rate) {
        uint256 _hamsterPrice = getHamsterPrice();
        if (_hamsterPrice <= hamsterPriceOne) {
            if (discountPercent == 0) {
                _rate = hamsterPriceOne;
            } else {
                uint256 _bondAmount = hamsterPriceOne.mul(1e18).div(_hamsterPrice);
                uint256 _discountAmount = _bondAmount.sub(hamsterPriceOne).mul(discountPercent).div(10000);
                _rate = hamsterPriceOne.add(_discountAmount);
                if (maxDiscountRate > 0 && _rate > maxDiscountRate) {
                    _rate = maxDiscountRate;
                }
            }
        }
    }

    function getBondPremiumRate() public view returns (uint256 _rate) {
        uint256 _hamsterPrice = getHamsterPrice();
        if (_hamsterPrice > hamsterPriceCeiling) {
            uint256 _hamsterPricePremiumThreshold = hamsterPriceOne.mul(premiumThreshold).div(100);
            if (_hamsterPrice >= _hamsterPricePremiumThreshold) {
                uint256 _premiumAmount = _hamsterPrice.sub(hamsterPriceOne).mul(premiumPercent).div(10000);
                _rate = hamsterPriceOne.add(_premiumAmount);
                if (maxPremiumRate > 0 && _rate > maxPremiumRate) {
                    _rate = maxPremiumRate;
                }
            } else {
                _rate = hamsterPriceOne;
            }
        }
    }

    function getHamsterCirculatingSupply() public view returns (uint256) {
        IERC20 hamsterErc20 = IERC20(hamster);
        uint256 totalSupply = hamsterErc20.totalSupply();
        uint256 balanceExcluded = 0;
        for (uint8 entryId = 0; entryId < excludedFromTotalSupply.length; ++entryId) {
            balanceExcluded = balanceExcluded.add(hamsterErc20.balanceOf(excludedFromTotalSupply[entryId]));
        }
        return totalSupply.sub(balanceExcluded);
    }

    function getHamsterPrice() public view returns (uint256 hamsterPrice) {
        try IOracle(hamsterOracle).consult(hamster, 1e18) returns (uint144 price) {
            return uint256(price);
        } catch {
            revert("Treasury: failed to consult HAMSTER price from the oracle");
        }
    }

    function nextEpochPoint() public view returns (uint256) {
        return startTime.add(epoch.mul(PERIOD));
    }

    event Initialized(address indexed executor, uint256 at);
    event BurnedBonds(address indexed from, uint256 bondAmount);
    event RedeemedBonds(address indexed from, uint256 hamsterAmount, uint256 bondAmount, uint256 epochNumber);
    event BoughtBonds(address indexed from, uint256 hamsterAmount, uint256 bondAmount, uint256 epochNumber);
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage, uint256 epochNumber);
    event HamsterWheelFunded(uint256 timestamp, uint256 seigniorage, uint256 epochNumber);
    event DaoFundFunded(uint256 timestamp, uint256 seigniorage, uint256 epochNumber);
    event DevFundFunded(uint256 timestamp, uint256 seigniorage, uint256 epochNumber);

    function allocateSeigniorage() external onlyOneBlock checkCondition checkEpoch checkOperator {
        _updateHamsterPrice();
        previousEpochHamsterPrice = getHamsterPrice();
        uint256 hamsterSupply = getHamsterCirculatingSupply().sub(seigniorageSaved);
        if (epoch < bootstrapEpochs) {
            _sendToHamsterWheel(hamsterSupply.mul(bootstrapSupplyExpansionPercent).div(10000));
        } else {
            if (previousEpochHamsterPrice > hamsterPriceCeiling) {
                uint256 bondSupply = IERC20(hamsterbond).totalSupply();
                uint256 _percentage = previousEpochHamsterPrice.sub(hamsterPriceOne);
                uint256 _savedForBond;
                uint256 _savedForHamsterWheel;
                uint256 _mse = _calculateMaxSupplyExpansionPercent(hamsterSupply).mul(1e14);
                if (_percentage > _mse) {
                    _percentage = _mse;
                }
                if (seigniorageSaved >= bondSupply.mul(bondDepletionFloorPercent).div(10000)) {
                    _savedForHamsterWheel = hamsterSupply.mul(_percentage).div(1e18);
                } else {
                    uint256 _seigniorage = hamsterSupply.mul(_percentage).div(1e18);
                    _savedForHamsterWheel = _seigniorage.mul(seigniorageExpansionFloorPercent).div(10000);
                    _savedForBond = _seigniorage.sub(_savedForHamsterWheel);
                    if (mintingFactorForPayingDebt > 0) {
                        _savedForBond = _savedForBond.mul(mintingFactorForPayingDebt).div(10000);
                    }
                }
                if (_savedForHamsterWheel > 0) {
                    _sendToHamsterWheel(_savedForHamsterWheel);
                }
                if (_savedForBond > 0) {
                    seigniorageSaved = seigniorageSaved.add(_savedForBond);
                    IBasisAsset(hamster).mint(address(this), _savedForBond);
                    emit TreasuryFunded(now, _savedForBond, epoch);
                }
            }
        }
    }

    function buyBonds(
        uint256 _hamsterAmount,
        uint256 targetPrice
    ) external onlyOneBlock checkCondition checkOperator {
        require(_hamsterAmount > 0, "Treasury: cannot purchase bonds with zero amount");
        uint256 hamsterPrice = getHamsterPrice();
        require(hamsterPrice == targetPrice, "Treasury: HAMSTER price moved");
        require(
            hamsterPrice < hamsterPriceOne,
            "Treasury: hamsterPrice not eligible for bond purchase"
        );
        require(_hamsterAmount <= epochSupplyContractionLeft, "Treasury: not enough bond left to purchase");
        uint256 _rate = getBondDiscountRate();
        require(_rate > 0, "Treasury: invalid bond rate");
        uint256 _bondAmount = _hamsterAmount.mul(_rate).div(1e18);
        uint256 hamsterSupply = getHamsterCirculatingSupply();
        uint256 newBondSupply = IERC20(hamsterbond).totalSupply().add(_bondAmount);
        require(newBondSupply <= hamsterSupply.mul(maxDebtRatioPercent).div(10000), "over max debt ratio");
        IBasisAsset(hamster).burnFrom(msg.sender, _hamsterAmount);
        IBasisAsset(hamsterbond).mint(msg.sender, _bondAmount);
        epochSupplyContractionLeft = epochSupplyContractionLeft.sub(_hamsterAmount);
        _updateHamsterPrice();
        emit BoughtBonds(msg.sender, _hamsterAmount, _bondAmount, epoch);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        require(address(_token) != address(hamster), "hamster");
        require(address(_token) != address(hamsterbond), "bond");
        require(address(_token) != address(hamstershare), "share");
        _token.safeTransfer(_to, _amount);
    }

    function hamsterWheelAllocateSeigniorage(uint256 amount) external onlyOperator {
        IHamsterWheel(hamsterWheel).allocateSeigniorage(amount);
    }

    function hamsterWheelGovernanceRecoverUnsupported(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IHamsterWheel(hamsterWheel).governanceRecoverUnsupported(_token, _amount, _to);
    }

    function hamsterWheelSetLockUp(
        uint256 _withdrawLockupEpochs,
        uint256 _rewardLockupEpochs
    ) external onlyOperator {
        IHamsterWheel(hamsterWheel).setLockUp(_withdrawLockupEpochs, _rewardLockupEpochs);
    }

    function hamsterWheelSetOperator(address _operator) external onlyOperator {
        IHamsterWheel(hamsterWheel).setOperator(_operator);
    }

    function initialize(
        address _hamster,
        address _hamsterbond,
        address _hamstershare,
        address _hamsterOracle,
        address _hamsterWheel,
        uint256 _startTime,
        address[] memory excludedFromTotalSupply_
    ) external notInitialized {
        hamster = _hamster;
        hamsterbond = _hamsterbond;
        hamstershare = _hamstershare;
        hamsterOracle = _hamsterOracle;
        hamsterWheel = _hamsterWheel;
        startTime = _startTime;
        hamsterPriceOne = 10**18;
        hamsterPriceCeiling = hamsterPriceOne.mul(101).div(100);
        supplyTiers = [
            0 ether,
            500000 ether,
            1000000 ether,
            1500000 ether,
            2000000 ether,
            5000000 ether,
            10000000 ether,
            20000000 ether,
            50000000 ether
        ];
        maxExpansionTiers = [
            450,
            400,
            350,
            300,
            250,
            200,
            150,
            125,
            100
        ];
        maxSupplyExpansionPercent = 400;
        bondDepletionFloorPercent = 10000;
        seigniorageExpansionFloorPercent = 3500;
        maxSupplyContractionPercent = 300;
        maxDebtRatioPercent = 3500;
        premiumThreshold = 110;
        premiumPercent = 7000;
        bootstrapEpochs = 28;
        bootstrapSupplyExpansionPercent = 450;
        seigniorageSaved = IERC20(hamster).balanceOf(address(this));
        initialized = true;
        operator = msg.sender;
        for (uint256 i = 0; i < excludedFromTotalSupply_.length; i++) {
            excludedFromTotalSupply.push(excludedFromTotalSupply_[i]);
            // HamsterGenesisPool && HamsterRewardPool
        }
        emit Initialized(msg.sender, block.number);
    }

    function redeemBonds(
        uint256 _bondAmount,
        uint256 targetPrice
    ) external onlyOneBlock checkCondition checkOperator {
        require(_bondAmount > 0, "Treasury: cannot redeem bonds with zero amount");
        uint256 hamsterPrice = getHamsterPrice();
        require(hamsterPrice == targetPrice, "Treasury: HAMSTER price moved");
        require(
            hamsterPrice > hamsterPriceCeiling,
            "Treasury: hamsterPrice not eligible for bond purchase"
        );
        uint256 _rate = getBondPremiumRate();
        require(_rate > 0, "Treasury: invalid bond rate");
        uint256 _hamsterAmount = _bondAmount.mul(_rate).div(1e18);
        require(IERC20(hamster).balanceOf(address(this)) >= _hamsterAmount, "Treasury: treasury has no more budget");
        seigniorageSaved = seigniorageSaved.sub(Math.min(seigniorageSaved, _hamsterAmount));
        IBasisAsset(hamsterbond).burnFrom(msg.sender, _bondAmount);
        IERC20(hamster).safeTransfer(msg.sender, _hamsterAmount);
        _updateHamsterPrice();
        emit RedeemedBonds(msg.sender, _hamsterAmount, _bondAmount, epoch);
    }

    function setBondDepletionFloorPercent(uint256 _bondDepletionFloorPercent) external onlyOperator {
        require(
            _bondDepletionFloorPercent >= 500 && _bondDepletionFloorPercent <= 10000,
            "out of range"
        );
        bondDepletionFloorPercent = _bondDepletionFloorPercent;
    }

    function setBootstrap(uint256 _bootstrapEpochs, uint256 _bootstrapSupplyExpansionPercent) external onlyOperator {
        require(_bootstrapEpochs <= 120, "_bootstrapEpochs: out of range");
        require(
            _bootstrapSupplyExpansionPercent >= 100 && _bootstrapSupplyExpansionPercent <= 1000,
            "_bootstrapSupplyExpansionPercent: out of range"
        );
        bootstrapEpochs = _bootstrapEpochs;
        bootstrapSupplyExpansionPercent = _bootstrapSupplyExpansionPercent;
    }

    function setDiscountPercent(uint256 _discountPercent) external onlyOperator {
        require(_discountPercent <= 20000, "_discountPercent is over 200%");
        discountPercent = _discountPercent;
    }

    function setExtraFunds(
        address _daoFund,
        uint256 _daoFundSharedPercent,
        address _devFund,
        uint256 _devFundSharedPercent
    ) external onlyOperator {
        require(_daoFund != address(0), "zero");
        require(_daoFundSharedPercent <= 3000, "out of range");
        require(_devFund != address(0), "zero");
        require(_devFundSharedPercent <= 1000, "out of range");
        daoFund = _daoFund;
        daoFundSharedPercent = _daoFundSharedPercent;
        devFund = _devFund;
        devFundSharedPercent = _devFundSharedPercent;
    }

    function setHamsterOracle(address _hamsterOracle) external onlyOperator {
        hamsterOracle = _hamsterOracle;
    }

    function setHamsterPriceCeiling(uint256 _hamsterPriceCeiling) external onlyOperator {
        require(
            _hamsterPriceCeiling >= hamsterPriceOne && _hamsterPriceCeiling <= hamsterPriceOne.mul(120).div(100),
            "out of range"
        );
        hamsterPriceCeiling = _hamsterPriceCeiling;
    }

    function setHamsterWheel(address _hamsterWheel) external onlyOperator {
        hamsterWheel = _hamsterWheel;
    }

    function setMaxDebtRatioPercent(uint256 _maxDebtRatioPercent) external onlyOperator {
        require(_maxDebtRatioPercent >= 1000 && _maxDebtRatioPercent <= 10000, "out of range");
        maxDebtRatioPercent = _maxDebtRatioPercent;
    }

    function setMaxDiscountRate(uint256 _maxDiscountRate) external onlyOperator {
        maxDiscountRate = _maxDiscountRate;
    }

    function setMaxExpansionTiersEntry(uint8 _index, uint256 _value) external onlyOperator returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < 9, "Index has to be lower than count of tiers");
        require(_value >= 10 && _value <= 1000, "_value: out of range");
        maxExpansionTiers[_index] = _value;
        return true;
    }

    function setMaxPremiumRate(uint256 _maxPremiumRate) external onlyOperator {
        maxPremiumRate = _maxPremiumRate;
    }

    function setMaxSupplyContractionPercent(uint256 _maxSupplyContractionPercent) external onlyOperator {
        require(
            _maxSupplyContractionPercent >= 100 && _maxSupplyContractionPercent <= 1500,
            "out of range"
        );
        maxSupplyContractionPercent = _maxSupplyContractionPercent;
    }

    function setMaxSupplyExpansionPercents(uint256 _maxSupplyExpansionPercent) external onlyOperator {
        require(
            _maxSupplyExpansionPercent >= 10 && _maxSupplyExpansionPercent <= 1000,
            "_maxSupplyExpansionPercent: out of range"
        );
        maxSupplyExpansionPercent = _maxSupplyExpansionPercent;
    }

    function setMintingFactorForPayingDebt(uint256 _mintingFactorForPayingDebt) external onlyOperator {
        require(
            _mintingFactorForPayingDebt >= 10000 && _mintingFactorForPayingDebt <= 20000,
            "_mintingFactorForPayingDebt: out of range"
        );
        mintingFactorForPayingDebt = _mintingFactorForPayingDebt;
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setPremiumPercent(uint256 _premiumPercent) external onlyOperator {
        require(_premiumPercent <= 20000, "_premiumPercent is over 200%");
        premiumPercent = _premiumPercent;
    }

    function setPremiumThreshold(uint256 _premiumThreshold) external onlyOperator {
        require(_premiumThreshold >= hamsterPriceCeiling, "_premiumThreshold exceeds hamsterPriceCeiling");
        require(_premiumThreshold <= 150, "_premiumThreshold is higher than 1.5");
        premiumThreshold = _premiumThreshold;
    }

    function setSupplyTiersEntry(uint8 _index, uint256 _value) external onlyOperator returns (bool) {
        require(_index >= 0, "Index has to be higher than 0");
        require(_index < 9, "Index has to be lower than count of tiers");
        if (_index > 0) {
            require(_value > supplyTiers[_index - 1]);
        }
        if (_index < 8) {
            require(_value < supplyTiers[_index + 1]);
        }
        supplyTiers[_index] = _value;
        return true;
    }

    function _calculateMaxSupplyExpansionPercent(uint256 _hamsterSupply) internal returns (uint256) {
        for (uint8 tierId = 8; tierId >= 0; --tierId) {
            if (_hamsterSupply >= supplyTiers[tierId]) {
                maxSupplyExpansionPercent = maxExpansionTiers[tierId];
                break;
            }
        }
        return maxSupplyExpansionPercent;
    }

    function _sendToHamsterWheel(uint256 _amount) internal {
        IBasisAsset(hamster).mint(address(this), _amount);
        uint256 _daoFundSharedAmount = 0;
        if (daoFundSharedPercent > 0) {
            _daoFundSharedAmount = _amount.mul(daoFundSharedPercent).div(10000);
            IERC20(hamster).transfer(daoFund, _daoFundSharedAmount);
            emit DaoFundFunded(now, _daoFundSharedAmount, epoch);
        }
        uint256 _devFundSharedAmount = 0;
        if (devFundSharedPercent > 0) {
            _devFundSharedAmount = _amount.mul(devFundSharedPercent).div(10000);
            IERC20(hamster).transfer(devFund, _devFundSharedAmount);
            emit DevFundFunded(now, _devFundSharedAmount, epoch);
        }
        _amount = _amount.sub(_daoFundSharedAmount).sub(_devFundSharedAmount);
        IERC20(hamster).safeApprove(hamsterWheel, 0);
        IERC20(hamster).safeApprove(hamsterWheel, _amount);
        IHamsterWheel(hamsterWheel).allocateSeigniorage(_amount);
        emit HamsterWheelFunded(now, _amount, epoch);
    }

    function _updateHamsterPrice() internal {
        try IOracle(hamsterOracle).update() {} catch {}
    }

    modifier checkCondition {
        require(now >= startTime, "Treasury: not started yet");
        _;
    }

    modifier checkEpoch {
        require(now >= nextEpochPoint(), "Treasury: not opened yet");
        _;
        epoch = epoch.add(1);
        epochSupplyContractionLeft = (getHamsterPrice() > hamsterPriceCeiling)
            ? 0
            : getHamsterCirculatingSupply().mul(maxSupplyContractionPercent).div(10000);
    }

    modifier checkOperator {
        require(
            IBasisAsset(hamster).operator() == address(this) &&
                IBasisAsset(hamsterbond).operator() == address(this) &&
                IBasisAsset(hamstershare).operator() == address(this) &&
                Operator(hamsterWheel).operator() == address(this),
            "Treasury: need more permission"
        );
        _;
    }

    modifier notInitialized {
        require(!initialized, "Treasury: already initialized");
        _;
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "Treasury: caller is not the operator");
        _;
    }
}
