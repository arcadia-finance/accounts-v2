/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { AccountV1 } from "../../src/AccountV1.sol";
import { BaseGuardian } from "../../src/guardians/BaseGuardian.sol";
import { FactoryGuardian } from "../../src/guardians/FactoryGuardian.sol";
import { MainRegistryGuardian } from "../../src/guardians/MainRegistryGuardian.sol";
import { MainRegistry } from "../../src/MainRegistry.sol";
import { MainRegistry_New } from "../../src/MainRegistry_New.sol";
import { IMainRegistry } from "../../src/interfaces/IMainRegistry_New.sol";
import { PricingModule_New } from "../../src/pricing-modules/AbstractPricingModule_New.sol";
import { PrimaryPricingModule } from "../../src/pricing-modules/AbstractPrimaryPricingModule.sol";
import { DerivedPricingModule } from "../../src/pricing-modules/AbstractDerivedPricingModule.sol";
import { UniswapV2PricingModule } from "../../src/pricing-modules/UniswapV2PricingModule.sol";
import { UniswapV3WithFeesPricingModule } from "../../src/pricing-modules/UniswapV3/UniswapV3WithFeesPricingModule.sol";
import { StandardERC4626PricingModule } from "../../src/pricing-modules/StandardERC4626PricingModule.sol";

contract AccountExtension is AccountV1 {
    constructor() AccountV1() { }

    function getLocked() external view returns (uint256 locked_) {
        locked_ = locked;
    }

    function setLocked(uint256 locked_) external {
        locked = locked_;
    }

    function getLengths() external view returns (uint256, uint256, uint256, uint256) {
        return (erc20Stored.length, erc721Stored.length, erc721TokenIds.length, erc1155Stored.length);
    }

    function setTrustedCreditor(address trustedCreditor_) public {
        trustedCreditor = trustedCreditor_;
    }

    function setIsTrustedCreditorSet(bool set) public {
        isTrustedCreditorSet = set;
    }

    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) public {
        fixedLiquidationCost = fixedLiquidationCost_;
    }

    function setOwner(address newOwner) public {
        owner = newOwner;
    }

    function setRegistry(address registry_) public {
        registry = registry_;
    }
}

contract BaseGuardianExtension is BaseGuardian {
    constructor() BaseGuardian() { }
}

contract FactoryGuardianExtension is FactoryGuardian {
    constructor() FactoryGuardian() { }

    function setPauseTimestamp(uint256 pauseTimestamp_) public {
        pauseTimestamp = pauseTimestamp_;
    }

    function setFlags(bool createPaused_, bool liquidatePaused_) public {
        createPaused = createPaused_;
        liquidatePaused = liquidatePaused_;
    }
}

contract MainRegistryGuardianExtension is MainRegistryGuardian {
    constructor() MainRegistryGuardian() { }

    function setPauseTimestamp(uint256 pauseTimestamp_) public {
        pauseTimestamp = pauseTimestamp_;
    }

    function setFlags(bool withdrawPaused_, bool depositPaused_) public {
        withdrawPaused = withdrawPaused_;
        depositPaused = depositPaused_;
    }
}

contract MainRegistryExtension is MainRegistry {
    using FixedPointMathLib for uint256;

    constructor(address factory_) MainRegistry(factory_) { }

    function setAssetType(address asset, uint96 assetType) public {
        assetToAssetInformation[asset].assetType = assetType;
    }

    function setPricingModuleForAsset(address asset, address pricingModule) public {
        assetToAssetInformation[asset].pricingModule = pricingModule;
    }
}

contract MainRegistryExtension_New is MainRegistry_New {
    using FixedPointMathLib for uint256;

    constructor(address factory_) MainRegistry_New(factory_) { }

    function setAssetType(address asset, uint96 assetType) public {
        assetToAssetInformation[asset].assetType = assetType;
    }

    function setPricingModuleForAsset(address asset, address pricingModule) public {
        assetToAssetInformation[asset].pricingModule = pricingModule;
    }
}

contract AbstractPricingModuleExtension is PricingModule_New {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        PricingModule_New(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function setRiskVariablesForAsset(address asset, RiskVarInput[] memory riskVarInputs) public {
        _setRiskVariablesForAsset(asset, riskVarInputs);
    }

    function setRiskVariables(address asset, uint256 basecurrency, RiskVars memory riskVars_) public {
        _setRiskVariables(asset, basecurrency, riskVars_);
    }
}

contract AbstractPrimaryPricingModuleExtension is PrimaryPricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        PrimaryPricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function setExposure(address asset, uint128 exposure_, uint128 maxExposure) public {
        exposure[asset].exposure = exposure_;
        exposure[asset].maxExposure = maxExposure;
    }

    // The function below is only needed in the case of testing for the "AbstractDerivedPricingModule", in order for the Primary Asset to return a value
    // getValue() will be tested separately per PM.
    function getValue(GetValueInput memory getValueInput)
        public
        pure
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // we assume a price of 1 for this testing purpose
        valueInUsd = getValueInput.assetAmount;
        collateralFactor = 0;
        liquidationFactor = 0;
    }
}

contract AbstractDerivedPricingModuleExtension is DerivedPricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        DerivedPricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    uint256 conversionRate;

    function setExposure(uint256 maxUsdExposureProtocol_, uint256 usdExposureProtocol_) public {
        maxUsdExposureProtocol = maxUsdExposureProtocol_;
        usdExposureProtocol = usdExposureProtocol_;
    }

    function setConversionRate(uint256 newConversionRate) public {
        conversionRate = newConversionRate;
    }

    function setAssetInformation(
        address asset,
        uint128 exposureAssetLast_,
        uint128 usdValueExposureAssetLast_,
        uint128[] memory exposureAssetToUnderlyingAssetLast
    ) public {
        assetToInformation[asset].exposureAssetLast = exposureAssetLast_;
        assetToInformation[asset].usdValueExposureAssetLast = usdValueExposureAssetLast_;
        assetToInformation[asset].exposureAssetToUnderlyingAssetsLast = exposureAssetToUnderlyingAssetLast;
    }

    function addAsset(address asset, address[] memory underlyingAssets_) public {
        require(!inPricingModule[asset], "ADPME_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].underlyingAssets = underlyingAssets_;

        uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](underlyingAssets_.length);

        assetToInformation[asset].exposureAssetToUnderlyingAssetsLast = exposureAssetToUnderlyingAssetsLast;
    }

    function _getConversionRate(address, address) internal view override returns (uint256 conversionRate_) {
        conversionRate_ = conversionRate;
    }
}

contract UniswapV2PricingModuleExtension is UniswapV2PricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address uniswapV2Factory_)
        UniswapV2PricingModule(mainRegistry_, oracleHub_, assetType_, uniswapV2Factory_)
    { }

    function getTrustedTokenAmounts(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 liquidityAmount
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) =
            _getTrustedTokenAmounts(pair, trustedPriceToken0, trustedPriceToken1, liquidityAmount);
    }

    function getTrustedReserves(address pair, uint256 trustedPriceToken0, uint256 trustedPriceToken1)
        public
        view
        returns (uint256 reserve0, uint256 reserve1)
    {
        (reserve0, reserve1) = _getTrustedReserves(pair, trustedPriceToken0, trustedPriceToken1);
    }

    function computeProfitMaximizingTrade(
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 reserve0,
        uint256 reserve1
    ) public pure returns (bool token0ToToken1, uint256 amountIn) {
        (token0ToToken1, amountIn) =
            _computeProfitMaximizingTrade(trustedPriceToken0, trustedPriceToken1, reserve0, reserve1);
    }

    function computeTokenAmounts(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount,
        uint256 kLast
    ) public view returns (uint256 token0Amount, uint256 token1Amount) {
        (token0Amount, token1Amount) = _computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getConversionRate(address asset, address underlyingAsset) public view returns (uint256 conversionRate) {
        conversionRate = _getConversionRate(asset, underlyingAsset);
    }
}

contract UniswapV3PricingModuleExtension is UniswapV3WithFeesPricingModule {
    constructor(address mainRegistry_, address oracleHub_, address riskManager_, address erc20PricingModule_)
        UniswapV3WithFeesPricingModule(mainRegistry_, oracleHub_, riskManager_, erc20PricingModule_)
    { }

    function getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 usdPriceToken0,
        uint256 usdPriceToken1
    ) public pure returns (uint256 amount0, uint256 amount1) {
        return _getPrincipalAmounts(tickLower, tickUpper, liquidity, usdPriceToken0, usdPriceToken1);
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public pure returns (uint160 sqrtPriceX96) {
        return _getSqrtPriceX96(priceToken0, priceToken1);
    }

    function getTrustedTickCurrent(address token0, address token1) public view returns (int256 tickCurrent) {
        return _getTrustedTickCurrent(token0, token1);
    }

    function setExposure(address asset, uint128 exposure_, uint128 maxExposure) public {
        exposure[asset].exposure = exposure_;
        exposure[asset].maxExposure = maxExposure;
    }

    function getFeeAmounts(address asset, uint256 id) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _getFeeAmounts(asset, id);
    }
}

contract ERC4626PricingModuleExtension is StandardERC4626PricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        StandardERC4626PricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function getConversionRate(address asset, address) public view returns (uint256 conversionRate) {
        conversionRate = _getConversionRate(asset, address(0));
    }
}
