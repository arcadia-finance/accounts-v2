/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { WrappedMetadex03AM } from "../../../src/asset-modules/Metadex03/WrappedMetadex03AM.sol";

contract WrappedMetadex03AMExtension is WrappedMetadex03AM {
    constructor(address owner_, address registry) WrappedMetadex03AM(owner_, registry) { }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        key = _getKeyFromAsset(asset, assetId);
    }

    function calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) public view returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssetKeys) {
        underlyingAssetKeys = _getUnderlyingAssets(assetKey);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 amount,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, amount, underlyingAssetKeys);
    }

    function getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
    }

    function getFeeBalances(
        WrappedMetadex03AM.PoolState memory poolState_,
        WrappedMetadex03AM.PositionState memory positionState_,
        uint256 fee0,
        uint256 fee1
    ) public pure returns (WrappedMetadex03AM.PoolState memory, WrappedMetadex03AM.PositionState memory) {
        return _getFeeBalances(poolState_, positionState_, fee0, fee1);
    }

    function setPoolState(address pool, WrappedMetadex03AM.PoolState memory poolState_) public {
        poolState[pool] = poolState_;
    }

    function setPositionState(uint256 positionId, WrappedMetadex03AM.PositionState memory positionState_) public {
        positionState[positionId] = positionState_;
    }

    function claimFees(address pool) public returns (uint256 fee0, uint256 fee1) {
        return _claimFees(pool);
    }

    function setTokens(address pool, address token0_, address token1_) public {
        token0[pool] = token0_;
        token1[pool] = token1_;
    }

    function getCurrentFees(address pool) public view returns (uint256 fee0, uint256 fee1) {
        return _getCurrentFees(pool);
    }

    function mintIdTo(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    function setOwnerOf(address owner_, uint256 positionId) public {
        _ownerOf[positionId] = owner_;
    }

    function setIdCounter(uint256 lastId_) public {
        lastPositionId = lastId_;
    }

    function setPoolInPosition(address pool, uint96 tokenId) public {
        positionState[tokenId].pool = pool;
    }
}
