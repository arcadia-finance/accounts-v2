/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { Currency } from "../../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { DerivedAM, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { FixedPoint96 } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/FixedPoint96.sol";
import { FixedPoint128 } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/FixedPoint128.sol";
import { FullMath } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/FullMath.sol";
import { Hooks } from "./libraries/Hooks.sol";
import { IPoolManager } from "../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { IPositionManager } from "./interfaces/IPositionManager.sol";
import { LiquidityAmounts } from "../UniswapV3/libraries/LiquidityAmounts.sol";
import { PoolId, PoolIdLibrary } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";
import { PoolKey } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { PositionInfoLibrary, PositionInfo } from "../../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";
import { StateLibrary } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import { TickMath } from "../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

/**
 * @title Asset Module for Uniswap V4 Liquidity Positions
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Uniswap V4 Liquidity Positions,
 * that have no permissions for the BEFORE_REMOVE_LIQUIDITY_FLAG and AFTER_REMOVE_LIQUIDITY_FLAG hooks.
 * @dev The DefaultUniswapV4AM will not price the LP tokens via direct price oracles,
 * it will break down liquidity positions in the underlying tokens (ERC20s).
 * Only LP tokens for which the underlying tokens are allowed as collateral can be priced.
 * @dev No end-user should directly interact with the DefaultUniswapV4AM, only the Registry,
 * or the contract owner.
 */
contract DefaultUniswapV4AM is DerivedAM {
    using FixedPointMathLib for uint256;
    using PoolIdLibrary for PoolKey;
    using PositionInfoLibrary for PositionInfo;
    using StateLibrary for IPoolManager;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the PoolManager.
    IPoolManager internal immutable POOL_MANAGER;

    // The contract address of the PositionManager.
    IPositionManager internal immutable POSITION_MANAGER;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The unique identifiers of the Underlying Assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) public assetToUnderlyingAssets;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error HooksNotAllowed();
    error InvalidAmount();
    error InvalidId();
    error ZeroLiquidity();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param positionManager The contract address of the uniswapV4 PositionManager.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for Uniswap V4 Liquidity Positions (ERC721).
     */
    constructor(address registry_, address positionManager) DerivedAM(registry_, 2) {
        POSITION_MANAGER = IPositionManager(positionManager);
        POOL_MANAGER = IPoolManager(POSITION_MANAGER.poolManager());
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset (Liquidity Position) to the DefaultUniswapV4AM.
     * @param assetId The id of the asset.
     * @dev All assets (Liquidity Positions) will have the same contract address (the PositionManager),
     * but a different id.
     * @dev No need to check if hooks are allowed, since for deposits this implicitly imposed
     * by the UniswapV4HooksRegistry, in getAssetModule().
     */
    function _addAsset(uint256 assetId) internal {
        if (assetId > type(uint96).max) revert InvalidId();

        (PoolKey memory poolKey, PositionInfo info) = POSITION_MANAGER.getPoolAndPositionInfo(assetId);
        bytes32 positionId =
            keccak256(abi.encodePacked(address(POSITION_MANAGER), info.tickLower(), info.tickUpper(), bytes32(assetId)));

        // Liquidity should be greater than zero.
        if (POOL_MANAGER.getPositionLiquidity(poolKey.toId(), positionId) == 0) revert ZeroLiquidity();

        // No need to explicitly check if token0 and token1 are allowed, _addAsset() is only called in the
        // deposit functions, and deposits of non-allowed Underlying Assets will revert.
        bytes32 assetKey = _getKeyFromAsset(address(POSITION_MANAGER), assetId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(Currency.unwrap(poolKey.currency0), 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(Currency.unwrap(poolKey.currency1), 0);
        assetToUnderlyingAssets[assetKey] = underlyingAssetKeys;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (asset != address(POSITION_MANAGER)) return false;

        try POSITION_MANAGER.getPoolAndPositionInfo(assetId) returns (PoolKey memory poolKey, PositionInfo info) {
            bytes32 positionId = keccak256(
                abi.encodePacked(address(POSITION_MANAGER), info.tickLower(), info.tickUpper(), bytes32(assetId))
            );

            // Hook flags should be valid for this specific AM.
            // The NoOP hook "AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG" is by default not allowed,
            // as it can only be accessed if "AFTER_REMOVE_LIQUIDITY_FLAG" is implemented.
            if (
                Hooks.hasPermission(uint160(address(poolKey.hooks)), Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG)
                    || Hooks.hasPermission(uint160(address(poolKey.hooks)), Hooks.AFTER_REMOVE_LIQUIDITY_FLAG)
            ) return false;

            // Underlying assets should be allowed and liquidity should be greater than zero.
            return IRegistry(REGISTRY).isAllowed(Currency.unwrap(poolKey.currency0), 0)
                && IRegistry(REGISTRY).isAllowed(Currency.unwrap(poolKey.currency1), 0)
                && POOL_MANAGER.getPositionLiquidity(poolKey.toId(), positionId) > 0;
        } catch {
            return false;
        }
    }

    /**
     * @notice Returns the unique identifiers of the Underlying Assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the Underlying Assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];

        if (underlyingAssetKeys.length == 0) {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited Liquidity Position.
            (, uint256 assetId) = _getAssetFromKey(assetKey);

            (PoolKey memory poolKey,) = POSITION_MANAGER.getPoolAndPositionInfo(assetId);

            underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = _getKeyFromAsset(Currency.unwrap(poolKey.currency0), 0);
            underlyingAssetKeys[1] = _getKeyFromAsset(Currency.unwrap(poolKey.currency1), 0);
        }
    }

    /**
     * @notice Calculates for a given asset the corresponding amount(s) of Underlying Asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the Underlying Assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 1e18 tokens of Underlying Asset, with 18 decimals precision.
     * @dev External price feeds of the Underlying Assets are used to calculate the flashloan resistant amounts.
     * This approach accommodates scenarios where an underlying asset could be
     * a derived asset itself (e.g., USDC/aUSDC pool), ensuring more versatile and accurate price calculations.
     */
    function _getUnderlyingAssetsAmounts(address creditor, bytes32 assetKey, uint256 amount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // Amount of a Uniswap V4 LP can only be either 0 or 1.
        if (amount == 0) {
            return (new uint256[](2), rateUnderlyingAssetsToUsd);
        }

        (, uint256 assetId) = _getAssetFromKey(assetKey);

        (PoolKey memory poolKey, PositionInfo info) = POSITION_MANAGER.getPoolAndPositionInfo(assetId);

        // Get the trusted rates to USD of the Underlying Assets.
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(Currency.unwrap(poolKey.currency0), 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(Currency.unwrap(poolKey.currency1), 0);
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // Calculate amount0 and amount1 of the principal (the actual liquidity position).
        bytes32 positionId =
            keccak256(abi.encodePacked(address(POSITION_MANAGER), info.tickLower(), info.tickUpper(), bytes32(assetId)));
        uint128 liquidity = POOL_MANAGER.getPositionLiquidity(poolKey.toId(), positionId);
        (uint256 principal0, uint256 principal1) = _getPrincipalAmounts(
            info, liquidity, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Calculate amount0 and amount1 of the accumulated fees.
        (uint256 fee0, uint256 fee1) = _getFeeAmounts(assetId, poolKey.toId(), info, liquidity);

        // As the sole liquidity provider in a new pool,
        // a malicious actor could bypass the max exposure by
        // continuously swapping large amounts and increasing the fee portion
        // of the liquidity position.
        // Therefore we cap the fee amounts so that this cannot be abused to far exceed the max exposures.
        unchecked {
            fee0 = fee0
                < principal0
                    + principal1.mulDivDown(rateUnderlyingAssetsToUsd[1].assetValue, rateUnderlyingAssetsToUsd[0].assetValue)
                ? fee0
                : principal0
                    + principal1.mulDivDown(rateUnderlyingAssetsToUsd[1].assetValue, rateUnderlyingAssetsToUsd[0].assetValue);
            fee1 = fee1
                < principal0.mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue)
                    + principal1
                ? fee1
                : principal0.mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue)
                    + principal1;

            underlyingAssetsAmounts = new uint256[](2);
            underlyingAssetsAmounts[0] = principal0 + fee0;
            underlyingAssetsAmounts[1] = principal1 + fee1;
        }
    }

    /**
     * @notice Calculates the underlying token amounts of a liquidity position, given external trusted prices.
     * @param info A packed struct including the poolId and the ticks of the position.
     * @param liquidity The liquidity of the specific position.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return amount0 The amount of underlying token0 tokens.
     * @return amount1 The amount of underlying token1 tokens.
     */
    function _getPrincipalAmounts(PositionInfo info, uint128 liquidity, uint256 priceToken0, uint256 priceToken1)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        // Calculate the square root of the relative rate sqrt(token1/token0) from the trusted USD price of both tokens.
        // sqrtPriceX96 is a binary fixed point number with 96 digits precision.
        uint160 sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);

        // Calculate amount0 and amount1 of the principal (the liquidity position without accumulated fees).
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(info.tickLower()),
            TickMath.getSqrtPriceAtTick(info.tickUpper()),
            liquidity
        );
    }

    /**
     * @notice Calculates the sqrtPriceX96 (token1/token0) from trusted USD prices of both tokens.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @dev The price in Uniswap V4 is defined as:
     * price = amountToken1/amountToken0.
     * The usdPriceToken is defined as: usdPriceToken = amountUsd/amountToken.
     * => amountToken = amountUsd/usdPriceToken.
     * Hence we can derive the Uniswap V4 price as:
     * price = (amountUsd/usdPriceToken1)/(amountUsd/usdPriceToken0) = usdPriceToken0/usdPriceToken1.
     */
    function _getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        if (priceToken1 == 0) return TickMath.MAX_SQRT_PRICE;

        // Both priceTokens have 18 decimals precision and result of division should have 28 decimals precision.
        // -> multiply by 1e28
        // priceXd28 will overflow if priceToken0 is greater than 1.158e+49.
        // For WBTC (which only has 8 decimals) this would require a bitcoin price greater than 115 792 089 237 316 198 989 824 USD/BTC.
        uint256 priceXd28 = priceToken0.mulDivDown(1e28, priceToken1);
        // Square root of a number with 28 decimals precision has 14 decimals precision.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        // Change sqrtPrice from a decimal fixed point number with 14 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd14 << FixedPoint96.RESOLUTION) / 1e14);
    }

    /**
     * @notice Calculates the underlying token amounts of accrued fees.
     * @param id The id of the Liquidity Position.
     * @param poolId The id of a UniswapV4 pool computed from the PoolKey.
     * @param info A packed struct including the poolId and the ticks of the position.
     * @param liquidity The liquidity of the specific position.
     * @return amount0 The amount of fees in underlying token0 tokens.
     * @return amount1 The amount of fees in underlying token1 tokens.
     */
    function _getFeeAmounts(uint256 id, PoolId poolId, PositionInfo info, uint128 liquidity)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128) =
            POOL_MANAGER.getFeeGrowthInside(poolId, info.tickLower(), info.tickUpper());

        bytes32 positionId =
            keccak256(abi.encodePacked(address(POSITION_MANAGER), info.tickLower(), info.tickUpper(), bytes32(id)));

        (, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) =
            POOL_MANAGER.getPositionInfo(poolId, positionId);

        // Calculate accumulated fees since the last time the position was updated:
        // (feeGrowthInsideCurrentX128 - feeGrowthInsideLastX128) * liquidity.
        // Fee calculations in PositionManager.sol overflow (without reverting) when
        // one or both terms, or their sum, is bigger than a uint128.
        // This is however much bigger than any realistic situation.
        unchecked {
            amount0 =
                FullMath.mulDiv(feeGrowthInside0CurrentX128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128);
            amount1 =
                FullMath.mulDiv(feeGrowthInside1CurrentX128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128);
        }
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
        uint256[] memory assetIds = new uint256[](2);

        (assets[0], assetIds[0]) = _getAssetFromKey(underlyingAssetKeys[0]);
        (assets[1], assetIds[1]) = _getAssetFromKey(underlyingAssetKeys[1]);

        (uint16[] memory collateralFactors, uint16[] memory liquidationFactors) =
            IRegistry(REGISTRY).getRiskFactors(creditor, assets, assetIds);

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

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on a direct deposit.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param amount The amount of tokens.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @dev super.processDirectDeposit checks that msg.sender is the Registry.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        returns (uint256 recursiveCalls)
    {
        // Amount deposited of a Uniswap V4 LP can be either 0 or 1 (checked in the Account).
        // For uniswap V4 every id is a unique asset -> on every deposit the asset must added to the Asset Module.
        if (amount == 1) _addAsset(assetId);

        // Also checks that msg.sender == Registry.
        recursiveCalls = super.processDirectDeposit(creditor, asset, assetId, amount);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     * @dev super.processIndirectDeposit checks that msg.sender is the Registry.
     * @dev deltaExposureUpperAssetToAsset of a Uniswap V4 LP must be either 0 or 1 for processIndirectDeposit().
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) {
        // deltaExposureUpperAssetToAsset of a Uniswap V4 LP can be either 0 or 1.
        // For uniswap V4 every id is a unique asset -> on a deposit, the asset must added to the Asset Module.
        if (deltaExposureUpperAssetToAsset == 1) _addAsset(assetId);
        else if (deltaExposureUpperAssetToAsset != 0) revert InvalidAmount();

        // Also checks that msg.sender == Registry.
        (recursiveCalls, usdExposureUpperAssetToAsset) = super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }
}
