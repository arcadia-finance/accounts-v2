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

import { FullMath } from "../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @title Asset-Module for Aerodrome Finance stable pools
 * @author Pragma Labs
 * @notice The AerodromeStableAM stores pricing logic and basic information for Aerodrome Finance stable pools.
 * @dev No end-user should directly interact with the AerodromeStableAM, only the Registry, the contract owner or via the actionHandler
 */
contract AerodromeStableAM is AerodromeVolatileAM {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps an asset to its underlying assets token decimals.
    mapping(address asset => UnderlyingAssetsDecimals) public underlyingAssetsDecimals;

    // Struct with the underlying assets token decimals.
    struct UnderlyingAssetsDecimals {
        uint64 decimals0;
        uint64 decimals1;
    }

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

        underlyingAssetsDecimals[pool] = UnderlyingAssetsDecimals({
            decimals0: uint64(10 ** ERC20(token0).decimals()),
            decimals1: uint64(10 ** ERC20(token1).decimals())
        });

        inAssetModule[pool] = true;

        bytes32[] memory underlyingAssetsKey = new bytes32[](2);
        underlyingAssetsKey[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetsKey[1] = _getKeyFromAsset(token1, 0);

        assetToUnderlyingAssets[_getKeyFromAsset(pool, 0)] = underlyingAssetsKey;

        // Will revert in Registry if Aerodrome pool was already added.
        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), pool);
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
        (address pool,) = _getAssetFromKey(assetKey);

        // Cache totalSupply
        uint256 totalSupply = IAeroPool(pool).totalSupply();
        if (totalSupply == 0) revert ZeroSupply();

        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        underlyingAssetsAmounts = new uint256[](2);

        // Cache assetValues
        uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue;
        uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue;

        // Get reserves
        (uint256 reserve0, uint256 reserve1,) = IAeroPool(pool).getReserves();

        // Get K : x3y+y3x
        // Note : check limit in terms of reserves (what would me max amount without risk of overflow)
        uint256 k;
        {
            uint256 x = reserve0 * 1e18 / underlyingAssetsDecimals[pool].decimals0;
            uint256 y = reserve1 * 1e18 / underlyingAssetsDecimals[pool].decimals1;
            uint256 a = x * y / 1e18;
            uint256 b = x * x / 1e18 + y * y / 1e18;
            k = a * b; // 36 decimals
        }

        // r'0 = sqrt{sqrt[k * p1 ** 3 / (p0 ** 3 + p0 * p1 ** 2)]}
        // -> r'0 = sqrt{p1 * sqrt[(k * p1 / p0) / (p0 ** 2 + p1 ** 2)]}
        uint256 c = FullMath.mulDiv(k, p1, p0); // 18 decimals
        uint256 d = p0.mulDivUp(p0, 1e18) + p1.mulDivUp(p1, 1e18); // 18 decimals
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e18, c, d)));

        // r1' = r0' * p0 / p1
        uint256 trustedReserve1 = FullMath.mulDiv(trustedReserve0, p0, p1);

        // Bring amount back from 18 decimals to actual decimals?
        trustedReserve0 = trustedReserve0 / (1e18 / underlyingAssetsDecimals[pool].decimals0);
        trustedReserve1 = trustedReserve1 / (1e18 / underlyingAssetsDecimals[pool].decimals1);

        underlyingAssetsAmounts[0] = trustedReserve0.mulDivDown(amount, totalSupply);
        underlyingAssetsAmounts[1] = trustedReserve1.mulDivDown(amount, totalSupply);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
