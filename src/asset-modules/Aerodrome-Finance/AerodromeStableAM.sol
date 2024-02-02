/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import {
    AerodromeVolatileAM,
    FixedPointMathLib,
    IRegistry,
    AssetValueAndRiskFactors,
    IAeroPool
} from "./AerodromeVolatileAM.sol";

/**
 * @title Asset-Module for Aerodrome Finance stable pools
 * @author Pragma Labs
 * @notice The AerodromeStableAM stores pricing logic and basic information for Aerodrome Finance stable pools.
 * @dev No end-user should directly interact with the AerodromeStableAM, only the Registry, the contract owner or via the actionHandler
 */
contract AerodromeStableAM is AerodromeVolatileAM {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error IsNotAStablePool();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param aerodromeFactory The contract address of the pool factory of Aerodrome Finance.
     */
    constructor(address registry_, address aerodromeFactory) AerodromeVolatileAM(registry_, aerodromeFactory) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Aerodrome stable pool to the AerodromeStableAM.
     * @param pool The contract address of the Aerodrome stable pool.
     */
    function addAsset(address pool) external override {
        if (AERO_FACTORY.isPool(pool) != true) revert InvalidPool();
        if (IAeroPool(pool).stable() != true) revert IsNotAStablePool();

        (address token0, address token1) = IAeroPool(pool).tokens();

        if (!IRegistry(REGISTRY).isAllowed(token0, 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(token1, 0)) revert AssetNotAllowed();

        inAssetModule[pool] = true;

        bytes32[] memory underlyingAssetsKey = new bytes32[](2);
        underlyingAssetsKey[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetsKey[1] = _getKeyFromAsset(token1, 0);

        assetToUnderlyingAssets[_getKeyFromAsset(pool, 0)] = underlyingAssetsKey;

        // Will revert in Registry if Aerodrome pool was already added.
        IRegistry(REGISTRY).addAsset(pool);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the Asset, in the decimal precision of the Asset.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 amount,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        //(address asset,) = _getAssetFromKey(assetKey);
        // Note : to implement
        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
