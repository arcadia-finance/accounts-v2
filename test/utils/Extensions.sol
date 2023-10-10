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
import { IMainRegistry } from "../../src/interfaces/IMainRegistry.sol";
import { PricingModule } from "../../src/pricing-modules/AbstractPricingModule.sol";
import { PrimaryPricingModule } from "../../src/pricing-modules/AbstractPrimaryPricingModule.sol";
import { DerivedPricingModule } from "../../src/pricing-modules/AbstractDerivedPricingModule.sol";
import { StandardERC20PricingModule } from "../../src/pricing-modules/StandardERC20PricingModule.sol";
import { StandardERC4626PricingModule } from "../../src/pricing-modules/StandardERC4626PricingModule.sol";
import { UniswapV2PricingModule } from "../../src/pricing-modules/UniswapV2PricingModule.sol";
import { UniswapV3WithFeesPricingModule } from "../../src/pricing-modules/UniswapV3/UniswapV3WithFeesPricingModule.sol";

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

contract AbstractPricingModuleExtension is PricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        PricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function setRiskVariablesForAsset(address asset, RiskVarInput[] memory riskVarInputs) public {
        _setRiskVariablesForAsset(asset, riskVarInputs);
    }

    function setRiskVariables(address asset, uint256 basecurrency, RiskVars memory riskVars_) public {
        _setRiskVariables(asset, basecurrency, riskVars_);
    }
}

contract AbstractPrimaryPricingModuleExtension is PrimaryPricingModule {
    // Price is 1 by default
    uint256 usdValueExposureToUnderlyingAsset = 1;

    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        PrimaryPricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function setPrice(uint256 usdValueExposureToUnderlyingAsset_) public {
        usdValueExposureToUnderlyingAsset = usdValueExposureToUnderlyingAsset_;
    }

    function setExposure(address asset, uint128 exposure_, uint128 maxExposure) public {
        exposure[asset].exposure = exposure_;
        exposure[asset].maxExposure = maxExposure;
    }

    // The function below is only needed in the case of testing for the "AbstractDerivedPricingModule", in order for the Primary Asset to return a value
    // getValue() will be tested separately per PM.
    function getValue(GetValueInput memory)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // we assume a price of 1 for this testing purpose
        valueInUsd = usdValueExposureToUnderlyingAsset;
        collateralFactor = 0;
        liquidationFactor = 0;
    }
}

contract AbstractDerivedPricingModuleExtension is DerivedPricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        DerivedPricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    uint256 public underlyingAssetsAmount;

    function getAssetToExposureLast(bytes32 assetKey)
        external
        view
        returns (uint128 exposureLast, uint128 usdValueExposureLast)
    {
        exposureLast = assetToExposureLast[assetKey].exposureLast;
        usdValueExposureLast = assetToExposureLast[assetKey].usdValueExposureLast;
    }

    function getExposureAssetToUnderlyingAssetsLast(bytes32 assetKey, bytes32 underlyingAssetKey)
        external
        view
        returns (uint256 exposureAssetToUnderlyingAssetsLast_)
    {
        exposureAssetToUnderlyingAssetsLast_ = exposureAssetToUnderlyingAssetsLast[assetKey][underlyingAssetKey];
    }

    function setUsdExposureProtocol(uint256 maxUsdExposureProtocol_, uint256 usdExposureProtocol_) public {
        maxUsdExposureProtocol = maxUsdExposureProtocol_;
        usdExposureProtocol = usdExposureProtocol_;
    }

    function setUnderlyingAssetsAmount(uint256 underlyingAssetsAmount_) public {
        underlyingAssetsAmount = underlyingAssetsAmount_;
    }

    function setAssetInformation(
        address asset,
        uint256 assetId,
        address underLyingAsset,
        uint256 underlyingAssetId,
        uint128 exposureAssetLast_,
        uint128 usdValueExposureAssetLast_,
        uint128 exposureAssetToUnderlyingAssetLast
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32 underLyingAssetKey = _getKeyFromAsset(underLyingAsset, underlyingAssetId);
        assetToExposureLast[assetKey].exposureLast = exposureAssetLast_;
        assetToExposureLast[assetKey].usdValueExposureLast = usdValueExposureAssetLast_;
        exposureAssetToUnderlyingAssetsLast[assetKey][underLyingAssetKey] = exposureAssetToUnderlyingAssetLast;
    }

    function addAsset(
        address asset,
        uint256 assetId,
        address[] memory underlyingAssets_,
        uint256[] memory underlyingAssetIds
    ) public {
        require(!inPricingModule[asset], "ADPME_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].underlyingAssets = underlyingAssets_;

        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](underlyingAssets_.length);
        for (uint256 i; i < underlyingAssets_.length;) {
            underlyingAssetKeys[i] = _getKeyFromAsset(underlyingAssets_[i], underlyingAssetIds[i]);
            ++i;
        }
        assetToUnderlyingAssets[assetKey] = underlyingAssetKeys;
    }

    function processDeposit(bytes32 assetKey, uint256 exposureAsset) public returns (uint256 usdValueExposureAsset) {
        usdValueExposureAsset = _processDeposit(assetKey, exposureAsset);
    }

    function getAndUpdateExposureAsset(bytes32 assetKey, int256 deltaAsset) public returns (uint256 exposureAsset) {
        exposureAsset = _getAndUpdateExposureAsset(assetKey, deltaAsset);
    }

    function processWithdrawal(bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdValueExposureAsset)
    {
        usdValueExposureAsset = _processWithdrawal(assetKey, exposureAsset);
    }

    function getAndUpdateExposureUnderlyingAsset(
        bytes32 assetKey,
        bytes32 UnderlyingAssetKey,
        uint256 exposureAsset,
        uint256 conversionRate_
    ) public returns (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) {
        (exposureAssetToUnderlyingAsset, deltaExposureAssetToUnderlyingAsset) =
            _getAndUpdateExposureUnderlyingAsset(assetKey, UnderlyingAssetKey, exposureAsset, conversionRate_);
    }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function _getUnderlyingAssetsAmounts(bytes32, uint256, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmount_)
    {
        underlyingAssetsAmount_ = new uint256[](1);
        underlyingAssetsAmount_[0] = underlyingAssetsAmount;
    }

    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssets)
    {
        underlyingAssets = assetToUnderlyingAssets[assetKey];
    }
}

contract StandardERC20PricingModuleExtension is StandardERC20PricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        StandardERC20PricingModule(mainRegistry_, oracleHub_, assetType_)
    { }

    function setExposure(address asset, uint128 exposure_, uint128 maxExposure) public {
        exposure[asset].exposure = exposure_;
        exposure[asset].maxExposure = maxExposure;
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

    function getUnderlyingAssetsAmounts(bytes32 assetKey, uint256 exposureAsset, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (uint256[] memory exposureAssetToUnderlyingAssets)
    {
        exposureAssetToUnderlyingAssets = _getUnderlyingAssetsAmounts(assetKey, exposureAsset, underlyingAssetKeys);
    }
}

contract UniswapV3PricingModuleExtension is UniswapV3WithFeesPricingModule {
    constructor(address mainRegistry_, address oracleHub_, address riskManager_)
        UniswapV3WithFeesPricingModule(mainRegistry_, oracleHub_, riskManager_)
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

    function getFeeAmounts(address asset, uint256 id) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _getFeeAmounts(asset, id);
    }
}

contract ERC4626PricingModuleExtension is StandardERC4626PricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        StandardERC4626PricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function getUnderlyingAssetsAmounts(bytes32 assetKey, uint256 exposureAsset, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (uint256[] memory exposureAssetToUnderlyingAssets)
    {
        exposureAssetToUnderlyingAssets = _getUnderlyingAssetsAmounts(assetKey, exposureAsset, underlyingAssetKeys);
    }
}
