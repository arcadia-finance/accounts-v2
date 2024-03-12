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
    mapping(address asset => AssetInformation) public assetToInformation;

    // Struct with the underlying assets token decimals.
    struct AssetInformation {
        uint64 unitCorrection0;
        uint64 unitCorrection1;
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

        assetToInformation[pool] = AssetInformation({
            unitCorrection0: uint64(10 ** (18 - ERC20(token0).decimals())),
            unitCorrection1: uint64(10 ** (18 - ERC20(token1).decimals()))
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
     * @dev The trusted reserves (r0' and r1') must satisfy two conditions:
     *  1) The pool is in equilibrium with external markets.
     *     r0' * P0usd = r1' * P1usd
     *     With P0usd and P1usd the trusted usd prices of both Underlying Assets.
     *  2) The invariant, k, of the pool is equal for both the trusted and untrusted reserves.
     *     k(r0', r1') = k(r0, r1)
     *     Stable aerodrome pools use a correction for the underlying token amounts to bring them to 18 decimals:
     *     x = r0 * 10^(18 - D0).
     *     y = r1 * 10^(18 - D1).
     *     The invariant is defined as: k = x³y + y³x
     * From these two conditions, the trusted reserves can be calculated as follows:
     *  3) We plug the definition of x and y into 1) and rewrite it as:
     *     y = x * [P0usd / 10^(18 - D0)] / [P1usd / 10^(18 - D1)]
     *     => y = x * p0 / p1
     *     With p0 = P0usd / 10^(18 - D0) and p1 = P1usd / 10^(18 - D1)
     *  4) We plug 3) into 2) and solve for x:
     *     x = ∜[k(r0, r1) * p1³ / (p0 * p1² + p0³)]
     *  5) Calculate r0' and r1' from x:
     *     r0' = x / 10^(18 - D0)
     *     r1' = r0' * P0usd / P1usd
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
        underlyingAssetsAmounts = new uint256[](2);
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // If one of the assets has a rate of 0, the whole LP positions will have a value of zero.
        if (rateUnderlyingAssetsToUsd[0].assetValue == 0 || rateUnderlyingAssetsToUsd[1].assetValue == 0) {
            return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
        }

        (address pool,) = _getAssetFromKey(assetKey);

        // Calculate k from the untrusted reserves:
        // k = x³y + y³x
        // => k = xy * (x² + y²)
        // => k = a * b
        // Note: we use 36 decimals precision for k, instead of the 18 decimals used in Aerodromes Pool.sol.
        uint256 k;
        uint256 unitCorrection0 = assetToInformation[pool].unitCorrection0;
        uint256 unitCorrection1 = assetToInformation[pool].unitCorrection1;
        {
            (uint256 reserve0, uint256 reserve1,) = IAeroPool(pool).getReserves();
            // Stable aerodrome pools use a correction for the underlying token amounts to bring them to 18 decimals:
            // x = r0 * 10^(18 - D0).
            // y = r1 * 10^(18 - D1).
            uint256 x = reserve0 * unitCorrection0; // 18 decimals.
            uint256 y = reserve1 * unitCorrection1; // 18 decimals.
            uint256 a = x.mulDivDown(y, 1e18); // 18 decimals.
            uint256 b = (x * x + y * y) / 1e18; // 18 decimals.
            k = a * b; // 36 decimals.
        }

        // Calculate x:
        // x = ∜[k(r0, r1) * p1³ / (p0 * p1² + p0³)]
        // => x = √{p1 * √[(k * p1 / p0) / (p0² + p1²)]}
        // => x = √{p1 * √[c / d]}
        uint256 trustedReserve0;
        {
            // USD rates also have to be corrected as shown in 3).
            uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue / unitCorrection0; // 18 decimals.
            uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue / unitCorrection1; // 18 decimals.
            uint256 c = FullMath.mulDiv(k, p1, p0); // 36 decimals.
            uint256 d = p0 * p0 + p1 * p1; // 36 decimals.
            // Sqrt halves the number of decimals.
            uint256 x = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d))); // 18 decimals.

            // Bring reserve0 from 18 decimals precision to the actual token decimals.
            // r0' = x / 10^(18 - D0).
            trustedReserve0 = x / unitCorrection0;
        }

        // r1' = r0' * P0usd / P1usd
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Cache totalSupply
        uint256 totalSupply = IAeroPool(pool).totalSupply();

        underlyingAssetsAmounts[0] = trustedReserve0.mulDivDown(amount, totalSupply);
        underlyingAssetsAmounts[1] = trustedReserve1.mulDivDown(amount, totalSupply);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
