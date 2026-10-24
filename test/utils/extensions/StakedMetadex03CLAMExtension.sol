/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StakedMetadex03CLAM } from "../../../src/asset-modules/Metadex03/StakedMetadex03CLAM.sol";

// forge-lint: disable-next-item(missing-inheritance)
contract StakedMetadex03CLAMExtension is StakedMetadex03CLAM {
    constructor(address owner_, address registry_, address gaugeFactory, address rewardToken, address surplusRecipient_)
        StakedMetadex03CLAM(owner_, registry_, gaugeFactory, rewardToken, surplusRecipient_)
    { }

    function getAeroVoter() public view returns (address aeroVoter) {
        aeroVoter = address(AERO_VOTER);
    }

    // forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function getCLFactory() public view returns (address cLFactory) {
        cLFactory = address(CL_FACTORY);
    }

    function getFactoryRegistry() public view returns (address factoryRegistry) {
        factoryRegistry = address(FACTORY_REGISTRY);
    }

    function getNonfungiblePositionManager() public view returns (address nonfungiblePositionManager) {
        nonfungiblePositionManager = address(NON_FUNGIBLE_POSITION_MANAGER);
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

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    function setPoolToGauge(address pool, address gauge) public {
        poolToGauge[pool] = gauge;
    }

    function rewardAmount(uint256 positionId) public pure returns (uint256 rewards) {
        rewards = _rewardAmount(positionId);
    }

    function asSingleton(uint256 positionId) public pure returns (uint256[] memory positionIds) {
        positionIds = _asSingleton(positionId);
    }

    function approvePosition(address gauge, uint256 assetId) public {
        NON_FUNGIBLE_POSITION_MANAGER.approve(gauge, assetId);
    }

    function stake(address gauge, uint256 assetId) public {
        _stake(gauge, assetId);
    }

    function withdrawAndClaim(address gauge, uint256 positionId) public {
        _withdrawAndClaim(gauge, positionId);
    }

    function claimReward(address gauge, uint256 positionId) public {
        _claimReward(gauge, positionId);
    }
}
