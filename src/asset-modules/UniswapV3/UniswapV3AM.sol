/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAM, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { FixedPoint96 } from "./libraries/FixedPoint96.sol";
import { FixedPoint128 } from "./libraries/FixedPoint128.sol";
import { FullMath } from "./libraries/FullMath.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { LiquidityAmounts } from "./libraries/LiquidityAmounts.sol";
import { PoolAddress } from "./libraries/PoolAddress.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { TickMath } from "./libraries/TickMath.sol";

/**
 * @title Asset Module for Uniswap V3 Liquidity Positions
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Uniswap V3 Liquidity Positions.
 * @dev The UniswapV3AM will not price the LP tokens via direct price oracles,
 * it will break down liquidity positions in the underlying tokens (ERC20s).
 * Only LP tokens for which the underlying tokens are allowed as collateral can be priced.
 * @dev No end-user should directly interact with the UniswapV3AM, only the Registry,
 * or the contract owner.
 */
contract UniswapV3AM is DerivedAM {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the NonfungiblePositionManager.
    INonfungiblePositionManager internal immutable NON_FUNGIBLE_POSITION_MANAGER;

    // The contract address of the Uniswap V3 (or exact clone) Factory.
    address internal immutable UNISWAP_V3_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The liquidity of the Liquidity Position when it was deposited.
    mapping(uint256 assetId => uint256 liquidity) internal assetToLiquidity;

    // The unique identifiers of the Underlying Assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InvalidId();
    error ZeroLiquidity();
    error InvalidAmount();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param nonFungiblePositionManager The contract address of the protocols NonFungiblePositionManager.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "1" for Uniswap V3 Liquidity Positions (ERC721).
     */
    constructor(address registry_, address nonFungiblePositionManager) DerivedAM(registry_, 1) {
        NON_FUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(nonFungiblePositionManager);
        UNISWAP_V3_FACTORY = INonfungiblePositionManager(nonFungiblePositionManager).factory();
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds the mapping from the NonfungiblePositionManager to this Asset Module in this Registry.
     * @dev Since all assets will have the same contract address, only the NonfungiblePositionManager has to be added to the Registry.
     */
    function setProtocol() external onlyOwner {
        inAssetModule[address(NON_FUNGIBLE_POSITION_MANAGER)] = true;

        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(address(NON_FUNGIBLE_POSITION_MANAGER));
    }

    /**
     * @notice Adds a new asset (Liquidity Position) to the UniswapV3AM.
     * @param assetId The id of the asset.
     * @dev All assets (Liquidity Positions) will have the same contract address (the NonfungiblePositionManager),
     * but a different id.
     */
    function _addAsset(uint256 assetId) internal {
        if (assetId > type(uint96).max) revert InvalidId();

        (,, address token0, address token1,,,, uint128 liquidity,,,,) = NON_FUNGIBLE_POSITION_MANAGER.positions(assetId);

        // No need to explicitly check if token0 and token1 are allowed, _addAsset() is only called in the
        // deposit functions and there any deposit of non-allowed Underlying Assets will revert.
        if (liquidity == 0) revert ZeroLiquidity();

        // The liquidity of the Liquidity Position is stored in the Asset Module,
        // not fetched from the NonfungiblePositionManager.
        // Since liquidity of a position can be increased by a non-owner,
        // the max exposure checks could otherwise be circumvented.
        assetToLiquidity[assetId] = liquidity;

        bytes32 assetKey = _getKeyFromAsset(address(NON_FUNGIBLE_POSITION_MANAGER), assetId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(token1, 0);
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
        if (asset != address(NON_FUNGIBLE_POSITION_MANAGER)) return false;

        try NON_FUNGIBLE_POSITION_MANAGER.positions(assetId) returns (
            uint96,
            address,
            address token0,
            address token1,
            uint24,
            int24,
            int24,
            uint128 liquidity,
            uint256,
            uint256,
            uint128,
            uint128
        ) {
            return IRegistry(REGISTRY).isAllowed(token0, 0) && IRegistry(REGISTRY).isAllowed(token1, 0) && liquidity > 0;
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
            (,, address token0, address token1,,,,,,,,) = NON_FUNGIBLE_POSITION_MANAGER.positions(assetId);

            underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = _getKeyFromAsset(token0, 0);
            underlyingAssetKeys[1] = _getKeyFromAsset(token1, 0);
        }
    }

    /**
     * @notice Calculates for a given asset the corresponding amount(s) of Underlying Asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * param assetAmount The amount of the asset, in the decimal precision of the Asset.
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
        // Amount of a Uniswap V3 LP can only be either 0 or 1.
        if (amount == 0) {
            return (new uint256[](2), rateUnderlyingAssetsToUsd);
        }

        (, uint256 assetId) = _getAssetFromKey(assetKey);

        (address token0, address token1, int24 tickLower, int24 tickUpper, uint128 liquidity) = _getPosition(assetId);

        // Get the trusted rates to USD of the Underlying Assets.
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(token1, 0);
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        // Calculate amount0 and amount1 of the principal (the actual liquidity position).
        (uint256 principal0, uint256 principal1) = _getPrincipalAmounts(
            tickLower,
            tickUpper,
            liquidity,
            rateUnderlyingAssetsToUsd[0].assetValue,
            rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Calculate amount0 and amount1 of the accumulated fees.
        (uint256 fee0, uint256 fee1) = _getFeeAmounts(assetId);

        // As the sole liquidity provider in a new pool,
        // a malicious actor could bypass the max exposure by
        // continiously swapping large amounts and increasing the fee portion
        // of the liquidity position.
        fee0 = fee0 > principal0 ? principal0 : fee0;
        fee1 = fee1 > principal1 ? principal1 : fee1;

        underlyingAssetsAmounts = new uint256[](2);
        unchecked {
            underlyingAssetsAmounts[0] = principal0 + fee0;
            underlyingAssetsAmounts[1] = principal1 + fee1;
        }
    }

    /**
     * @notice Returns the position information.
     * @param assetId The id of the asset.
     * @return token0 Token0 of the Liquidity Pool.
     * @return token1 Token1 of the Liquidity Pool.
     * @return tickLower The lower tick of the liquidity position.
     * @return tickUpper The upper tick of the liquidity position.
     * @return liquidity The liquidity per tick of the liquidity position.
     */
    function _getPosition(uint256 assetId)
        internal
        view
        returns (address token0, address token1, int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        // For deposited assets, the liquidity of the Liquidity Position is stored in the Asset Module,
        // not fetched from the NonfungiblePositionManager.
        // Since liquidity of a position can be increased by a non-owner, the max exposure checks could otherwise be circumvented.
        liquidity = uint128(assetToLiquidity[assetId]);

        if (liquidity > 0) {
            (,, token0, token1,, tickLower, tickUpper,,,,,) = NON_FUNGIBLE_POSITION_MANAGER.positions(assetId);
        } else {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited Liquidity Position.
            (,, token0, token1,, tickLower, tickUpper, liquidity,,,,) = NON_FUNGIBLE_POSITION_MANAGER.positions(assetId);
        }
    }

    /**
     * @notice Calculates the underlying token amounts of a liquidity position, given external trusted prices.
     * @param tickLower The lower tick of the liquidity position.
     * @param tickUpper The upper tick of the liquidity position.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return amount0 The amount of underlying token0 tokens.
     * @return amount1 The amount of underlying token1 tokens.
     */
    function _getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 priceToken0,
        uint256 priceToken1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        // Calculate the square root of the relative rate sqrt(token1/token0) from the trusted USD price of both tokens.
        // sqrtPriceX96 is a binary fixed point number with 96 digits precision.
        uint160 sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);

        // Calculate amount0 and amount1 of the principal (the liquidity position without accumulated fees).
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    /**
     * @notice Calculates the sqrtPriceX96 (token1/token0) from trusted USD prices of both tokens.
     * @param priceToken0 The price of 1e18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 1e18 tokens of token1 in USD, with 18 decimals precision.
     * @return sqrtPriceX96 The square root of the price (token1/token0), with 96 binary precision.
     * @dev The price in Uniswap V3 is defined as:
     * price = amountToken1/amountToken0.
     * The usdPriceToken is defined as: usdPriceToken = amountUsd/amountToken.
     * => amountToken = amountUsd/usdPriceToken.
     * Hence we can derive the Uniswap V3 price as:
     * price = (amountUsd/usdPriceToken1)/(amountUsd/usdPriceToken0) = usdPriceToken0/usdPriceToken1.
     */
    function _getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) internal pure returns (uint160 sqrtPriceX96) {
        if (priceToken1 == 0) return TickMath.MAX_SQRT_RATIO;

        // Both priceTokens have 18 decimals precision and result of division should also have 18 decimals precision.
        // -> multiply by 1e18
        uint256 priceXd18 = priceToken0.mulDivDown(1e18, priceToken1);
        // Square root of a number with 18 decimals precision has 9 decimals precision.
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        // Change sqrtPrice from a decimal fixed point number with 9 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd9 << FixedPoint96.RESOLUTION) / 1e9);
    }

    /**
     * @notice Calculates the underlying token amounts of accrued fees, both collected and uncollected.
     * @param id The id of the Liquidity Position.
     * @return amount0 The amount of fees in underlying token0 tokens.
     * @return amount1 The amount of fees in underlying token1 tokens.
     */
    function _getFeeAmounts(uint256 id) internal view returns (uint256 amount0, uint256 amount1) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidity, // gas: cheaper to use uint256 instead of uint128.
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint256 tokensOwed0, // gas: cheaper to use uint256 instead of uint128.
            uint256 tokensOwed1 // gas: cheaper to use uint256 instead of uint128.
        ) = NON_FUNGIBLE_POSITION_MANAGER.positions(id);

        (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128) =
            _getFeeGrowthInside(token0, token1, fee, tickLower, tickUpper);

        // Calculate the total amount of fees by adding the already realized fees (tokensOwed),
        // to the accumulated fees since the last time the position was updated:
        // (feeGrowthInsideCurrentX128 - feeGrowthInsideLastX128) * liquidity.
        // Fee calculations in NonfungiblePositionManager.sol overflow (without reverting) when
        // one or both terms, or their sum, is bigger than a uint128.
        // This is however much bigger than any realistic situation.
        unchecked {
            amount0 = FullMath.mulDiv(
                feeGrowthInside0CurrentX128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed0;
            amount1 = FullMath.mulDiv(
                feeGrowthInside1CurrentX128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed1;
        }
    }

    /**
     * @notice Calculates the current fee growth inside the Liquidity Range.
     * @param token0 Token0 of the Liquidity Pool.
     * @param token1 Token1 of the Liquidity Pool.
     * @param fee The fee of the Liquidity Pool.
     * @param tickLower The lower tick of the liquidity position.
     * @param tickUpper The upper tick of the liquidity position.
     * @return feeGrowthInside0X128 The amount of fees in underlying token0 tokens.
     * @return feeGrowthInside1X128 The amount of fees in underlying token1 tokens.
     */
    function _getFeeGrowthInside(address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper)
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(UNISWAP_V3_FACTORY, token0, token1, fee));

        // To calculate the pending fees, the current tick has to be used, even if the pool would be unbalanced.
        (, int24 tickCurrent,,,,,) = pool.slot0();
        (,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,) = pool.ticks(tickLower);
        (,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,) = pool.ticks(tickUpper);

        // Calculate the fee growth inside of the Liquidity Range since the last time the position was updated.
        // feeGrowthInside can overflow (without reverting), as is the case in the Uniswap fee calculations.
        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                feeGrowthInside0X128 =
                    pool.feeGrowthGlobal0X128() - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 =
                    pool.feeGrowthGlobal1X128() - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            }
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
     * @return assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155
     * ...
     * @dev super.processDirectDeposit checks that msg.sender is the Registry.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        returns (uint256 recursiveCalls, uint256 assetType)
    {
        // Amount deposited of a Uniswap V3 LP can be either 0 or 1 (checked in the Account).
        // For uniswap V3 every id is a unique asset -> on every deposit the asset must added to the Asset Module.
        if (amount == 1) _addAsset(assetId);

        // Also checks that msg.sender == Registry.
        (recursiveCalls, assetType) = super.processDirectDeposit(creditor, asset, assetId, amount);
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
     * @dev deltaExposureUpperAssetToAsset of a Uniswap V3 LP must be either 0 or 1 for processIndirectDeposit().
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) {
        // deltaExposureUpperAssetToAsset of a Uniswap V3 LP can be either 0 or 1.
        // For uniswap V3 every id is a unique asset -> on a deposit, the asset must added to the Asset Module.
        if (deltaExposureUpperAssetToAsset == 1) _addAsset(assetId);
        else if (deltaExposureUpperAssetToAsset != 0) revert InvalidAmount();

        // Also checks that msg.sender == Registry.
        (recursiveCalls, usdExposureUpperAssetToAsset) = super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }

    /**
     * @notice Decreases the exposure to an asset on a direct withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param amount The amount of tokens.
     * @dev super.processDirectWithdrawal checks that msg.sender is the Registry.
     * @dev If the asset is withdrawn, remove its liquidity from the mapping.
     * If we would keep the liquidity of the asset in storage,
     * _getUnderlyingAssets() would keep using the liquidity of the asset at the time of deposit.
     * This might result in a wrongly calculated getValue() of the non-deposited asset (for off-chain purposes).
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        returns (uint256 assetType)
    {
        // Also checks that msg.sender == Registry.
        assetType = super.processDirectWithdrawal(creditor, asset, assetId, amount);

        // Amount withdrawn of a Uniswap V3 LP can be either 0 or 1 (checked in the Account).
        if (amount == 1) delete assetToLiquidity[assetId];
    }

    /**
     * @notice Decreases the exposure to an asset on an indirect withdrawal.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     * @dev super.processIndirectWithdrawal checks that msg.sender is the Registry.
     * @dev If the asset is withdrawn, remove its liquidity from the mapping.
     * If we would keep the liquidity of the asset in storage,
     * _getUnderlyingAssets() would keep using the liquidity of the asset at the time of deposit.
     * This might result in a wrongly calculated getValue() of the non-deposited asset (for off-chain purposes).
     * @dev deltaExposureUpperAssetToAsset of a Uniswap V3 LP must be either 0 or -1 for processIndirectWithdrawal().
     * But we do NOT revert if the value is different from 0 or -1, since this would block withdrawals and hence liquidations,
     * which is worse as having wrongly calculated exposures.
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (uint256 usdExposureUpperAssetToAsset) {
        // Also checks that msg.sender == Registry.
        usdExposureUpperAssetToAsset = super.processIndirectWithdrawal(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // deltaExposureUpperAssetToAsset of a Uniswap V3 LP can be either 0 or -1.
        if (deltaExposureUpperAssetToAsset == -1) delete assetToLiquidity[assetId];
    }
}
