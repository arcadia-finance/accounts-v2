/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DerivedAssetModule, FixedPointMathLib, IMainRegistry } from "../AbstractDerivedAssetModule.sol";
import { FixedPoint96 } from "./libraries/FixedPoint96.sol";
import { FixedPoint128 } from "./libraries/FixedPoint128.sol";
import { FullMath } from "./libraries/FullMath.sol";
import { INonfungiblePositionManager } from "./interfaces/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { LiquidityAmounts } from "./libraries/LiquidityAmounts.sol";
import { PoolAddress } from "./libraries/PoolAddress.sol";
import { SafeCastLib } from "lib/solmate/src/utils/SafeCastLib.sol";
import { RiskModule } from "../../RiskModule.sol";
import { TickMath } from "./libraries/TickMath.sol";

/**
 * @title Asset Module for Uniswap V3 Liquidity Positions.
 * @author Pragma Labs
 * @notice The pricing logic and basic information for Uniswap V3 Liquidity Positions.
 * @dev The UniswapV3AssetModule will not price the LP-tokens via direct price oracles,
 * it will break down liquidity positions in the underlying tokens (ERC20s).
 * Only LP tokens for which the underlying tokens are allowed as collateral can be priced.
 * @dev No end-user should directly interact with the UniswapV3AssetModule, only the Main-registry,
 * or the contract owner.
 */
contract UniswapV3AssetModule is DerivedAssetModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the NonfungiblePositionManager.
    address internal immutable NON_FUNGIBLE_POSITION_MANAGER;

    // The contract address of the Uniswap V3 (or exact clone) Factory.
    address internal immutable UNISWAP_V3_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The liquidity of the Liquidity Position when it was deposited.
    mapping(uint256 assetId => uint256 liquidity) internal assetToLiquidity;

    // The Unique identifiers of the underlying assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param nonFungiblePositionManager The contract address of the protocols NonFungiblePositionManager.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for Uniswap V3 Liquidity Positions (ERC721) is 1.
     */
    constructor(address mainRegistry_, address nonFungiblePositionManager) DerivedAssetModule(mainRegistry_, 1) {
        NON_FUNGIBLE_POSITION_MANAGER = nonFungiblePositionManager;
        UNISWAP_V3_FACTORY = INonfungiblePositionManager(nonFungiblePositionManager).factory();
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds the mapping from the NonfungiblePositionManager to this Asset Module in this MainRegistry.
     * @dev Since all assets will have the same contract address, the NonfungiblePositionManager has to be added to the MainRegistry.
     */
    function setProtocol() external onlyOwner {
        inAssetModule[NON_FUNGIBLE_POSITION_MANAGER] = true;

        // Will revert in MainRegistry if asset was already added.
        IMainRegistry(MAIN_REGISTRY).addAsset(NON_FUNGIBLE_POSITION_MANAGER, ASSET_TYPE);
    }

    /**
     * @notice Adds a new asset (Liquidity Position) to the UniswapV3AssetModule.
     * @param assetId The Id of the asset.
     * @dev All assets (Liquidity Positions) will have the same contract address (the NonfungiblePositionManager),
     * but a different id.
     */
    function _addAsset(uint256 assetId) internal {
        require(assetId <= type(uint96).max, "AMUV3_AA: Id too large");

        (,, address token0, address token1,,,, uint128 liquidity,,,,) =
            INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).positions(assetId);

        // No need to explicitly check if token0 and token1 are allowed, _addAsset() is only called in the
        // deposit functions and there any deposit of non-allowed underlying assets will revert.
        require(liquidity > 0, "AMUV3_AA: 0 liquidity");

        assetToLiquidity[assetId] = liquidity;

        bytes32 assetKey = _getKeyFromAsset(NON_FUNGIBLE_POSITION_MANAGER, assetId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(token1, 0);
        assetToUnderlyingAssets[assetKey] = underlyingAssetKeys;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (asset != NON_FUNGIBLE_POSITION_MANAGER) return false;

        try INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).positions(assetId) returns (
            uint96,
            address,
            address token0,
            address token1,
            uint24,
            int24,
            int24,
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        ) {
            return
                IMainRegistry(MAIN_REGISTRY).isAllowed(token0, 0) && IMainRegistry(MAIN_REGISTRY).isAllowed(token1, 0);
        } catch {
            return false;
        }
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

        if (underlyingAssetKeys.length == 0) {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited Liquidity Position.
            (, uint256 assetId) = _getAssetFromKey(assetKey);
            (,, address token0, address token1,,,,,,,,) =
                INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).positions(assetId);

            underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = _getKeyFromAsset(token0, 0);
            underlyingAssetKeys[1] = _getKeyFromAsset(token1, 0);
        }
    }

    /**
     * @notice Calculates for a given asset id the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @dev Uniswap Pools can be manipulated, we can't rely on the current price (or tick) stored in slot0.
     * We use Chainlink oracles of the underlying assets to calculate the flashloan resistant amounts.
     */
    function _getUnderlyingAssetsAmounts(address creditor, bytes32 assetKey, uint256, bytes32[] memory)
        internal
        view
        override
        returns (
            uint256[] memory underlyingAssetsAmounts,
            RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (, uint256 assetId) = _getAssetFromKey(assetKey);

        (address token0, address token1, int24 tickLower, int24 tickUpper, uint128 liquidity) = _getPosition(assetId);

        // Get the trusted rates to USD of the underlying assets.
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

        // ToDo: fee should be capped to a max compared to principal to avoid circumventing caps via fees on new pools.

        underlyingAssetsAmounts = new uint256[](2);
        underlyingAssetsAmounts[0] = principal0 + fee0;
        underlyingAssetsAmounts[1] = principal1 + fee1;
    }

    /**
     * @notice Returns the position information.
     * @param assetId The Id of the asset.
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
            (,, token0, token1,, tickLower, tickUpper,,,,,) =
                INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).positions(assetId);
        } else {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited Liquidity Position.
            (,, token0, token1,, tickLower, tickUpper, liquidity,,,,) =
                INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).positions(assetId);
        }
    }

    /**
     * @notice Calculates the underlying token amounts of a liquidity position, given external trusted prices.
     * @param tickLower The lower tick of the liquidity position.
     * @param tickUpper The upper tick of the liquidity position.
     * @param priceToken0 The price of 10^18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 10^18 tokens of token1 in USD, with 18 decimals precision.
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
        // Calculate the square root of the relative rate sqrt(token1/token0) from the trusted USD-price of both tokens.
        // sqrtPriceX96 is a binary fixed point number with 96 digits precision.
        uint160 sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);

        // Calculate amount0 and amount1 of the principal (the liquidity position without accumulated fees).
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    /**
     * @notice Calculates the sqrtPriceX96 (token1/token0) from trusted USD prices of both tokens.
     * @param priceToken0 The price of 10^18 tokens of token0 in USD, with 18 decimals precision.
     * @param priceToken1 The price of 10^18 tokens of token1 in USD, with 18 decimals precision.
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
        // -> multiply by 10**18
        uint256 priceXd18 = priceToken0.mulDivDown(1e18, priceToken1);
        // Square root of a number with 18 decimals precision has 9 decimals precision.
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        // Change sqrtPrice from a decimal fixed point number with 9 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd9 << FixedPoint96.RESOLUTION) / 1e9);
    }

    /**
     * @notice Calculates the underlying token amounts of accrued fees, both collected as uncollected.
     * @param id The Id of the Liquidity Position.
     * @return amount0 The amount fees of underlying token0 tokens.
     * @return amount1 The amount of fees underlying token1 tokens.
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
        ) = INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).positions(id);

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
     * @return feeGrowthInside0X128 The amount fees of underlying token0 tokens.
     * @return feeGrowthInside1X128 The amount of fees underlying token1 tokens.
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
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on a direct deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        onlyMainReg
    {
        // For uniswap V3 every id is a unique asset -> on every deposit the asset must added to the Asset Module.
        _addAsset(assetId);

        super.processDirectDeposit(creditor, asset, assetId, amount);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Asset Module.
     * @return usdExposureUpperAssetToAsset The Usd value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyMainReg returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        // For uniswap V3 every id is a unique asset -> on every deposit the asset must added to the Asset Module.
        _addAsset(assetId);

        (primaryFlag, usdExposureUpperAssetToAsset) = super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }
}
