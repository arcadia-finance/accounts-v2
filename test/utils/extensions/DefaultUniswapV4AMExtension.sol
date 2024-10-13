/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { DefaultUniswapV4AM } from "../../../src/asset-modules/UniswapV4/DefaultUniswapV4AM.sol";
import { PoolId } from "../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolId.sol";
import { PoolKey } from "../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PositionInfo } from "../../../lib/v4-periphery-fork/src/libraries/PositionInfoLibrary.sol";

contract DefaultUniswapV4AMExtension is DefaultUniswapV4AM {
    constructor(address registry_, address positionManager) DefaultUniswapV4AM(registry_, positionManager) { }

    function getAssetExposureLast(address creditor, bytes32 assetKey)
        external
        view
        returns (uint128 lastExposureAsset, uint128 lastUsdExposureAsset)
    {
        lastExposureAsset = lastExposuresAsset[creditor][assetKey].lastExposureAsset;
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

    function getPositionManager() public view returns (address positionManager) {
        positionManager = address(POSITION_MANAGER);
    }

    function getUniswapV4PoolManager() public view returns (address poolManager) {
        poolManager = address(POOL_MANAGER);
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
            AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getPrincipalAmounts(PositionInfo info, uint128 liquidity, uint256 usdPriceToken0, uint256 usdPriceToken1)
        public
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        return _getPrincipalAmounts(info, liquidity, usdPriceToken0, usdPriceToken1);
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public pure returns (uint160 sqrtPriceX96) {
        return _getSqrtPriceX96(priceToken0, priceToken1);
    }

    function getFeeAmounts(uint256 id, PoolId poolId, PositionInfo info, uint128 liquidity)
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = _getFeeAmounts(id, poolId, info, liquidity);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
