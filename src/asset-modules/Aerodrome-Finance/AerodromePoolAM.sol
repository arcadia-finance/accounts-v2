/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DerivedAM, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { FullMath } from "../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { IAeroFactory } from "./interfaces/IAeroFactory.sol";
import { IAeroPool } from "./interfaces/IAeroPool.sol";

/**
 * @title Asset-Module for Aerodrome Finance Pools
 * @author Pragma Labs
 * @notice The AerodromePoolAM stores pricing logic and basic information for Aerodrome Finance Pools
 * @dev No end-user should directly interact with the AerodromePoolAM, only the Registry, the contract owner or via the actionHandler
 */
contract AerodromePoolAM is DerivedAM {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The Aerodrome Finance Factory
    IAeroFactory public immutable AERO_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps an Aerodrome Finance pool to its underlying assets.
    mapping(bytes32 asset => bytes32[] underlyingAssets) public assetToUnderlyingAssets;

    // Maps an asset to its struct with information.
    mapping(address asset => AssetInformation) public assetToInformation;

    // Struct with additional information for a specific pool.
    struct AssetInformation {
        bool stable;
        uint64 unitCorrection0;
        uint64 unitCorrection1;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error InvalidPool();
    error OnlyOwner();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param aerodromeFactory The contract address of the pool factory of Aerodrome Finance.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "1" for ERC20 tokens.
     */
    constructor(address registry_, address aerodromeFactory) DerivedAM(registry_, 1) {
        AERO_FACTORY = IAeroFactory(aerodromeFactory);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Aerodrome pool to the AerodromePoolAM.
     * @param pool The contract address of the Aerodrome Finance pool.
     */
    function addAsset(address pool) external {
        if (AERO_FACTORY.isPool(pool) != true) revert InvalidPool();

        (address token0, address token1) = IAeroPool(pool).tokens();
        if (!IRegistry(REGISTRY).isAllowed(token0, 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(token1, 0)) revert AssetNotAllowed();

        if (IAeroPool(pool).stable()) {
            // Only owner can add Stable pools, since tokens with very high supply (>15511800964 * 10 ** decimals)
            // might cause an overflow in _getTrustedReservesStable().
            if (msg.sender != owner) revert OnlyOwner();

            assetToInformation[pool] = AssetInformation({
                stable: true,
                unitCorrection0: uint64(10 ** (18 - ERC20(token0).decimals())),
                unitCorrection1: uint64(10 ** (18 - ERC20(token1).decimals()))
            });
        }

        inAssetModule[pool] = true;

        bytes32[] memory underlyingAssetsKey = new bytes32[](2);
        underlyingAssetsKey[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetsKey[1] = _getKeyFromAsset(token1, 0);

        assetToUnderlyingAssets[_getKeyFromAsset(pool, 0)] = underlyingAssetsKey;

        // Will revert in Registry if Aerodrome Finance pool was already added.
        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), pool);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @return allowed A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool allowed) {
        if (inAssetModule[asset]) allowed = true;
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Asset Module are ERC20's.
     */
    function _getKeyFromAsset(address asset, uint256) internal pure override returns (bytes32 key) {
        assembly {
            key := asset
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The Id of the asset.
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Asset Module are ERC20's.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];
    }

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
        underlyingAssetsAmounts = new uint256[](2);
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // If one of the assets has a rate of 0, the whole LP positions will have a value of zero.
        if (rateUnderlyingAssetsToUsd[0].assetValue == 0 || rateUnderlyingAssetsToUsd[1].assetValue == 0) {
            return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
        }

        (address pool,) = _getAssetFromKey(assetKey);

        // Calculate the trusted reserves of the pool.
        (uint256 trustedReserve0, uint256 trustedReserve1) = assetToInformation[pool].stable
            ? _getTrustedReservesStable(pool, rateUnderlyingAssetsToUsd)
            : _getTrustedReservesVolatile(pool, rateUnderlyingAssetsToUsd);

        // Cache totalSupply
        uint256 totalSupply = IAeroPool(pool).totalSupply();

        underlyingAssetsAmounts[0] = trustedReserve0.mulDivDown(amount, totalSupply);
        underlyingAssetsAmounts[1] = trustedReserve1.mulDivDown(amount, totalSupply);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /**
     * @notice Calculates the trusted reserves of a volatile Aerodrome pool.
     * @param pool The contract address of the pool.
     * @param rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return trustedReserve0 The trusted reserve of token0.
     * @return trustedReserve1 The trusted reserve of token1.
     * @dev The trusted reserves (r0' and r1') must satisfy two conditions:
     *  1) The pool is in equilibrium with external markets.
     *     r0' * P0usd = r1' * P1usd
     *     With P0usd and P1usd the trusted usd prices of both Underlying Assets.
     *  2) The invariant, k, of the pool is equal for both the trusted and untrusted reserves.
     *     k(r0', r1') = k(r0, r1)
     *     The invariant is defined as: k(r0, r1) = r0 * r1
     * From these two conditions, the trusted reserves can be calculated as follows:
     *  3) Condition 1) can be rewritten as:
     *     r1' = r0' * P0usd / P1usd
     *  4) We plug 3) into 2) and solve for r0':
     *     r0' = √[P1usd * k / P0usd]
     *  5) Calculate r1' from r1':
     *     r1' = r0' * P0usd / P1usd
     */
    function _getTrustedReservesVolatile(address pool, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
        internal
        view
        returns (uint256 trustedReserve0, uint256 trustedReserve1)
    {
        // Calculate k from the untrusted reserves:
        // k = r0 * r1
        (uint256 reserve0, uint256 reserve1,) = IAeroPool(pool).getReserves();
        uint256 k = reserve0 * reserve1;

        // Calculate trusted reserves:
        // r0' = √[P1usd * k / P0usd]
        trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );

        // r1' = r0' * P0usd / P1usd
        trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );
    }

    /**
     * @notice Calculates the trusted reserves of a stable Aerodrome pool.
     * @param pool The contract address of the pool.
     * @param rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return trustedReserve0 The trusted reserve of token0.
     * @return trustedReserve1 The trusted reserve of token1.
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
    function _getTrustedReservesStable(address pool, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
        internal
        view
        returns (uint256 trustedReserve0, uint256 trustedReserve1)
    {
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
        trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors of an asset for a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(_getKeyFromAsset(asset, assetId));

        address[] memory assets = new address[](2);
        (assets[0],) = _getAssetFromKey(underlyingAssetKeys[0]);
        (assets[1],) = _getAssetFromKey(underlyingAssetKeys[1]);

        (uint16[] memory collateralFactors, uint16[] memory liquidationFactors) =
            IRegistry(REGISTRY).getRiskFactors(creditor, assets, new uint256[](2));

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;

        // Keep the lowest risk factor of all underlying assets.
        // Unsafe cast: collateralFactor and liquidationFactor are smaller than or equal to 1e4.
        collateralFactor = uint16(
            collateralFactors[0] < collateralFactors[1]
                ? riskFactor.mulDivDown(collateralFactors[0], AssetValuationLib.ONE_4)
                : riskFactor.mulDivDown(collateralFactors[1], AssetValuationLib.ONE_4)
        );
        liquidationFactor = uint16(
            liquidationFactors[0] < liquidationFactors[1]
                ? riskFactor.mulDivDown(liquidationFactors[0], AssetValuationLib.ONE_4)
                : riskFactor.mulDivDown(liquidationFactors[1], AssetValuationLib.ONE_4)
        );
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev We take the most conservative (lowest) risk factor of all underlying assets.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) internal view override returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        valueInUsd = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18)
            + underlyingAssetsAmounts[1].mulDivDown(rateUnderlyingAssetsToUsd[1].assetValue, 1e18);

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;

        // Keep the lowest risk factor of all underlying assets.
        collateralFactor = rateUnderlyingAssetsToUsd[0].collateralFactor < rateUnderlyingAssetsToUsd[1].collateralFactor
            ? riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[0].collateralFactor, AssetValuationLib.ONE_4)
            : riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[1].collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor = rateUnderlyingAssetsToUsd[0].liquidationFactor
            < rateUnderlyingAssetsToUsd[1].liquidationFactor
            ? riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[0].liquidationFactor, AssetValuationLib.ONE_4)
            : riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[1].liquidationFactor, AssetValuationLib.ONE_4);
    }
}
