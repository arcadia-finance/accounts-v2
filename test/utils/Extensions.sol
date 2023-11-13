/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { AccountV1 } from "../../src/AccountV1.sol";
import { BaseGuardian } from "../../src/guardians/BaseGuardian.sol";
import { DerivedPricingModule } from "../../src/pricing-modules/AbstractDerivedPricingModule.sol";
import { FactoryGuardian } from "../../src/guardians/FactoryGuardian.sol";
import { FloorERC721PricingModule } from "../../src/pricing-modules/FloorERC721PricingModule.sol";
import { FloorERC1155PricingModule } from "../../src/pricing-modules/FloorERC1155PricingModule.sol";
import { MainRegistryGuardian } from "../../src/guardians/MainRegistryGuardian.sol";
import { MainRegistry } from "../../src/MainRegistry.sol";
import { PricingModule } from "../../src/pricing-modules/AbstractPricingModule.sol";
import { PrimaryPricingModule } from "../../src/pricing-modules/AbstractPrimaryPricingModule.sol";
import { RiskModule } from "../../src/RiskModule.sol";
import { StandardERC20PricingModule } from "../../src/pricing-modules/StandardERC20PricingModule.sol";
import { StandardERC4626PricingModule } from "../../src/pricing-modules/StandardERC4626PricingModule.sol";
import { UniswapV2PricingModule } from "../../src/pricing-modules/UniswapV2PricingModule.sol";
import { UniswapV3PricingModule } from "../../src/pricing-modules/UniswapV3/UniswapV3PricingModule.sol";
import { ActionMultiCall } from "../../src/actions/MultiCall.sol";

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

contract RiskModuleExtension {
    function calculateCollateralValue(RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        external
        pure
        returns (uint256 collateralValue)
    {
        collateralValue = RiskModule._calculateCollateralValue(valuesAndRiskFactors);
    }

    function calculateLiquidationValue(RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        external
        pure
        returns (uint256 liquidationValue)
    {
        liquidationValue = RiskModule._calculateLiquidationValue(valuesAndRiskFactors);
    }
}

abstract contract AbstractPricingModuleExtension is PricingModule {
    constructor(address mainRegistry_, uint256 assetType_) PricingModule(mainRegistry_, assetType_) { }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}

abstract contract AbstractPrimaryPricingModuleExtension is PrimaryPricingModule {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        PrimaryPricingModule(mainRegistry_, oracleHub_, assetType_)
    { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function setExposure(
        address creditor,
        address asset,
        uint256 assetId,
        uint128 lastExposureAsset,
        uint128 maxExposure
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        riskParams[creditor][assetKey].lastExposureAsset = lastExposureAsset;
        riskParams[creditor][assetKey].maxExposure = maxExposure;
    }
}

abstract contract AbstractDerivedPricingModuleExtension is DerivedPricingModule {
    constructor(address mainRegistry_, uint256 assetType_) DerivedPricingModule(mainRegistry_, assetType_) { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function getAssetExposureLast(address creditor, bytes32 assetKey)
        external
        view
        returns (uint128 lastExposureAsset_, uint128 lastUsdExposureAsset)
    {
        lastExposureAsset_ = lastExposuresAsset[creditor][assetKey].lastExposureAsset;
        lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
    }

    function getExposureAssetToUnderlyingAssetsLast(address creditor, bytes32 assetKey, bytes32 underlyingAssetKey)
        external
        view
        returns (uint256 exposureAssetToUnderlyingAssetsLast_)
    {
        exposureAssetToUnderlyingAssetsLast_ =
            lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKey];
    }

    function setUsdExposureProtocol(address creditor, uint128 maxUsdExposureProtocol_, uint128 usdExposureProtocol_)
        public
    {
        riskParams[creditor].maxUsdExposureProtocol = maxUsdExposureProtocol_;
        riskParams[creditor].lastUsdExposureProtocol = usdExposureProtocol_;
    }

    function setAssetInformation(
        address creditor,
        address asset,
        uint256 assetId,
        address underLyingAsset,
        uint256 underlyingAssetId,
        uint128 exposureAssetLast,
        uint128 lastUsdExposureAsset,
        uint128 exposureAssetToUnderlyingAssetLast
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32 underLyingAssetKey = _getKeyFromAsset(underLyingAsset, underlyingAssetId);
        lastExposuresAsset[creditor][assetKey].lastExposureAsset = exposureAssetLast;
        lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = lastUsdExposureAsset;
        lastExposureAssetToUnderlyingAsset[creditor][assetKey][underLyingAssetKey] = exposureAssetToUnderlyingAssetLast;
    }

    function getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
    }

    function processDeposit(address creditor, bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdExposureAsset)
    {
        usdExposureAsset = _processDeposit(creditor, assetKey, exposureAsset);
    }

    function getAndUpdateExposureAsset(address creditor, bytes32 assetKey, int256 deltaAsset)
        public
        returns (uint256 exposureAsset)
    {
        exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, deltaAsset);
    }

    function processWithdrawal(address creditor, bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdExposureAsset)
    {
        usdExposureAsset = _processWithdrawal(creditor, assetKey, exposureAsset);
    }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}

contract StandardERC20PricingModuleExtension is StandardERC20PricingModule {
    constructor(address mainRegistry_, address oracleHub_) StandardERC20PricingModule(mainRegistry_, oracleHub_) { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function setExposure(address creditor, address asset, uint128 lastExposureAsset, uint128 maxExposure) public {
        bytes32 assetKey = _getKeyFromAsset(asset, 0);
        riskParams[creditor][assetKey].lastExposureAsset = lastExposureAsset;
        riskParams[creditor][assetKey].maxExposure = maxExposure;
    }
}

contract FloorERC721PricingModuleExtension is FloorERC721PricingModule {
    constructor(address mainRegistry_, address oracleHub_) FloorERC721PricingModule(mainRegistry_, oracleHub_) { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}

contract FloorERC1155PricingModuleExtension is FloorERC1155PricingModule {
    constructor(address mainRegistry_, address oracleHub_) FloorERC1155PricingModule(mainRegistry_, oracleHub_) { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }
}

contract UniswapV2PricingModuleExtension is UniswapV2PricingModule {
    constructor(address mainRegistry_, address uniswapV2Factory_)
        UniswapV2PricingModule(mainRegistry_, uniswapV2Factory_)
    { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUniswapV2Factory() external view returns (address uniswapV2Factory) {
        uniswapV2Factory = UNISWAP_V2_FACTORY;
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssets(address asset) public view returns (address[] memory underlyingAssets) {
        underlyingAssets = new address[](2);

        bytes32 assetKey = _getKeyFromAsset(asset, 0);
        bytes32[] memory underlyingAssetKeys = assetToUnderlyingAssets[assetKey];
        (underlyingAssets[0],) = _getAssetFromKey(underlyingAssetKeys[0]);
        (underlyingAssets[1],) = _getAssetFromKey(underlyingAssetKeys[1]);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

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
}

contract UniswapV3PricingModuleExtension is UniswapV3PricingModule {
    constructor(address mainRegistry_, address nonfungiblePositionManager)
        UniswapV3PricingModule(mainRegistry_, nonfungiblePositionManager)
    { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function getNonFungiblePositionManager() public view returns (address nonFungiblePositionManager) {
        nonFungiblePositionManager = NON_FUNGIBLE_POSITION_MANAGER;
    }

    function getUniswapV3Factory() public view returns (address uniswapV3Factory) {
        uniswapV3Factory = UNISWAP_V3_FACTORY;
    }

    function getAssetToLiquidity(uint256 assetId) external view returns (uint256 liquidity) {
        liquidity = assetToLiquidity[assetId];
    }

    function addAsset(uint256 assetId) public {
        _addAsset(assetId);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getPosition(uint256 assetId)
        public
        view
        returns (address token0, address token1, int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        return _getPosition(assetId);
    }

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

    function getFeeAmounts(uint256 id) public view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _getFeeAmounts(id);
    }
}

contract ERC4626PricingModuleExtension is StandardERC4626PricingModule {
    constructor(address mainRegistry_) StandardERC4626PricingModule(mainRegistry_) { }

    function getPrimaryFlag() public pure returns (bool primaryFlag) {
        primaryFlag = PRIMARY_FLAG;
    }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }
}

contract MultiCallExtention is ActionMultiCall {
    function assets() public view returns (address[] memory) {
        return mintedAssets;
    }

    function ids() public view returns (uint256[] memory) {
        return mintedIds;
    }

    function setMintedAssets(address[] memory mintedAssets_) public {
        mintedAssets = mintedAssets_;
    }

    function setMintedIds(uint256[] memory mintedIds_) public {
        mintedIds = mintedIds_;
    }
}
