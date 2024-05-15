/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ActionData, IActionBase } from "../interfaces/IActionBase.sol";
import { AssetValueAndRiskFactors } from "../libraries/AssetValuationLib.sol";
import {
    CollectParams,
    IncreaseLiquidityParams,
    INonfungiblePositionManager
} from "./interfaces/INonfungiblePositionManager.sol";
import { ERC20, SafeTransferLib } from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { FixedPoint96 } from "../asset-modules/UniswapV3/libraries/FixedPoint96.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { IPermit2 } from "../interfaces/IPermit2.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { ISwapRouter, ExactInputSingleParams } from "./interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";
import { SafeCastLib } from "../../lib/solmate/src/utils/SafeCastLib.sol";
import { TickMath } from "../asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @title AutoCompounder UniswapV3
 * @author Pragma Labs
 * @notice The AutoCompounder will act as an Asset Manager for Arcadia Accounts.
 * It will allow third parties to trigger the compounding functionality for the Account.
 * Compounding can only be triggered if certain conditions are met and the initiator will get a small fee for the service provided.
 * The compounding will collect the fees earned by a position and increase the liquidity of the position by those fees.
 * Depending on current tick of the pool and the position range, fees will be deposited in appropriate ratio.
 */
contract AutoCompounder is IActionBase {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The Uniswap V3 Factory contract.
    IUniswapV3Factory public immutable UNI_V3_FACTORY;
    // The contract address of the Registry.
    IRegistry public immutable REGISTRY;
    // The Uniswap V3 NonfungiblePositionManager contract.
    INonfungiblePositionManager public immutable NONFUNGIBLE_POSITIONMANAGER;
    // The UniswapV3 SwapRouter contract.
    ISwapRouter public immutable SWAP_ROUTER;

    // Max upper deviation in sqrtPriceX96 (reflecting the upper limit for the actual price increase)
    uint256 public immutable MAX_UPPER_SQRT_PRICE_DEVIATION;
    // Max lower deviation in sqrtPriceX96 (reflecting the lower limit for the actual price increase)
    uint256 public immutable MAX_LOWER_SQRT_PRICE_DEVIATION;
    // Basis Points (one basis point is equivalent to 0.01%)
    uint256 internal constant BIPS = 10_000;
    // Tolerance in BIPS for max price deviation and slippage
    uint256 public immutable TOLERANCE;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Storage variable for the Account for which to compound fees.
    address internal account;

    // A struct with variables to track for a specific position.
    struct PositionData {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
    }

    // A struct with variables to track in order to calculate fee ratios.
    struct FeeData {
        uint256 usdPriceToken0;
        uint256 usdPriceToken1;
        uint256 feeAmount0;
        uint256 feeAmount1;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error PriceToleranceExceeded();
    error CallerIsNotAccount();
    error MaxToleranceExceeded();

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The contract address of the Registry.
     * @param uniswapV3Factory The contract address of the Uniswap V3 Factory.
     * @param nonfungiblePositionManager The contract address of Uniswap V3 NonFungiblePositionManager.
     * @param swapRouter The contract address of the Uniswap V3 SwapRouter.
     * @param tolerance The max deviation of the internal pool price of assets compared to external price of assets (relative price), in BIPS.
     * @dev The tolerance will be converted to an upper and lower max sqrtPrice deviation, using the square root of basis + tolerance value. As the relationship between
     * sqrtPriceX96 and actual price is quadratic, amplifying changes in the latter when the former alters slightly.
     */
    constructor(
        address registry,
        address uniswapV3Factory,
        address nonfungiblePositionManager,
        address swapRouter,
        uint256 tolerance
    ) {
        // Tolerance should never be higher than 50%
        if (tolerance > 5000) revert MaxToleranceExceeded();
        UNI_V3_FACTORY = IUniswapV3Factory(uniswapV3Factory);
        REGISTRY = IRegistry(registry);
        NONFUNGIBLE_POSITIONMANAGER = INonfungiblePositionManager(nonfungiblePositionManager);
        SWAP_ROUTER = ISwapRouter(swapRouter);
        TOLERANCE = tolerance;

        // sqrtPrice to price has a quadratic relationship thus we need to take the square root of max percentage price deviation.
        MAX_UPPER_SQRT_PRICE_DEVIATION = FixedPointMathLib.sqrt((BIPS + tolerance) * BIPS);
        MAX_LOWER_SQRT_PRICE_DEVIATION = FixedPointMathLib.sqrt((BIPS - tolerance) * BIPS);
    }

    /* ///////////////////////////////////////////////////////////////
                             COMPOUNDING LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will compound the fees earned by a position owned by an Arcadia Account.
     * @param account_ The Arcadia Account owning the position.
     * @param assetId The position id to compound the fees for.
     */
    // TODO : trigger for compounding ? Earned fee ?
    function compoundFeesForAccount(address account_, uint256 assetId) external {
        // Cache Account in storage, used to validate caller for executeAction()
        account = account_;

        address[] memory assets_ = new address[](1);
        assets_[0] = address(NONFUNGIBLE_POSITIONMANAGER);
        uint256[] memory assetIds_ = new uint256[](1);
        assetIds_[0] = assetId;
        uint256[] memory assetAmounts_ = new uint256[](1);
        assetAmounts_[0] = 1;
        uint256[] memory assetTypes_ = new uint256[](1);
        assetTypes_[0] = 2;

        ActionData memory assetData =
            ActionData({ assets: assets_, assetIds: assetIds_, assetAmounts: assetAmounts_, assetTypes: assetTypes_ });

        // Empty data needed to encode in actionData
        bytes memory signature;
        ActionData memory transferFromOwner;
        IPermit2.PermitBatchTransferFrom memory permit;

        bytes memory compounderData = abi.encode(assetData, msg.sender);
        bytes memory actionData = abi.encode(assetData, transferFromOwner, permit, signature, compounderData);

        // Trigger flashAction with actionTarget as this contract
        IAccount(account_).flashAction(address(this), actionData);

        // executeAction() triggered as callback function
    }

    /**
     * @notice Callback function called in the Arcadia Account.
     * @param actionData A bytes object containing one actionData struct and the address of the initiator.
     * @dev This function will trigger the following actions :
     * - Verify that the pool's current price remains within the defined tolerance range of external price.
     * - Collects the fees earned by the position.
     * - Calculates the current ratio at which fees should be deposited in position, swaps one token to another if needed.
     * - Increases the liquidity of the current position with those fees.
     * - Transfers dust amounts to the initiator.
     */
    function executeAction(bytes calldata actionData) external override returns (ActionData memory assetData) {
        // Position transferred from Account
        // Caller should be the Account provided as input in compoundFeesForAccount()
        if (msg.sender != account) revert CallerIsNotAccount();

        // Decode bytes data
        address initiator;
        (assetData, initiator) = abi.decode(actionData, (ActionData, address));

        PositionData memory posData;
        // Cache tokenId
        uint256 tokenId = assetData.assetIds[0];
        (,, posData.token0, posData.token1, posData.fee, posData.tickLower, posData.tickUpper,,,,,) =
            NONFUNGIBLE_POSITIONMANAGER.positions(tokenId);

        // Check that sqrtPriceX96 is in limits to avoid front-running
        FeeData memory feeData;
        int24 currentTick;
        uint160 sqrtPriceX96;
        (currentTick, sqrtPriceX96, feeData.usdPriceToken0, feeData.usdPriceToken1) =
            _sqrtPriceX96InLimits(posData.token0, posData.token1, posData.fee);

        // Collect fees
        CollectParams memory collectParams = CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (feeData.feeAmount0, feeData.feeAmount1) = NONFUNGIBLE_POSITIONMANAGER.collect(collectParams);

        // Get amounts to deposit for current range of position
        _handleFeeRatiosForDeposit(currentTick, posData, feeData, sqrtPriceX96);

        // Increase liquidity in pool
        uint256 amount0ToDeposit = ERC20(posData.token0).balanceOf(address(this));
        uint256 amount1ToDeposit = ERC20(posData.token1).balanceOf(address(this));
        IncreaseLiquidityParams memory increaseLiquidityParams = IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0ToDeposit,
            amount1Desired: amount1ToDeposit,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        ERC20(posData.token0).approve(address(NONFUNGIBLE_POSITIONMANAGER), amount0ToDeposit);
        ERC20(posData.token1).approve(address(NONFUNGIBLE_POSITIONMANAGER), amount1ToDeposit);
        INonfungiblePositionManager(address(NONFUNGIBLE_POSITIONMANAGER)).increaseLiquidity(increaseLiquidityParams);

        // Dust amounts are transfered to the initiator
        ERC20(posData.token0).safeTransfer(initiator, ERC20(posData.token0).balanceOf(address(this)));
        ERC20(posData.token1).safeTransfer(initiator, ERC20(posData.token1).balanceOf(address(this)));

        // Position is deposited back to the Account
        NONFUNGIBLE_POSITIONMANAGER.approve(msg.sender, tokenId);
    }

    /**
     * @notice Internal function to ensure the pool's current price remains within the specified tolerance range of the external price.
     * @param token0 The contract address of token 0 of the position.
     * @param token1 The contract address of token 1 of the position.
     * @param fee The fee of the pool to which the position is related.
     * @return currentTick The current tick of the pool.
     * @return sqrtPriceX96 The current value of sqrtPriceX96 in the pool.
     * @return usdPriceToken0 The oracle price of token0 for 1e18 tokens.
     * @return usdPriceToken1 The oracle price of token1 for 1e18 tokens.
     */
    function _sqrtPriceX96InLimits(address token0, address token1, uint24 fee)
        internal
        view
        returns (int24 currentTick, uint160 sqrtPriceX96, uint256 usdPriceToken0, uint256 usdPriceToken1)
    {
        // Get sqrtPriceX96 from pool
        address pool = UNI_V3_FACTORY.getPool(token0, token1, fee);
        (sqrtPriceX96, currentTick,,,,,) = IUniswapV3Pool(pool).slot0();

        // Get current prices for 1e18 amount of assets
        address[] memory assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;
        uint256[] memory assetIds = new uint256[](2);
        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1e18;
        assetAmounts[1] = 1e18;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            REGISTRY.getValuesInUsd(address(0), assets, assetIds, assetAmounts);

        usdPriceToken0 = valuesAndRiskFactors[0].assetValue;
        usdPriceToken1 = valuesAndRiskFactors[1].assetValue;

        // Recalculate sqrtPriceX96 based on external prices
        uint160 sqrtPriceX96Calculated = _getSqrtPriceX96(usdPriceToken0, usdPriceToken1);
        int24 currentTickCalculated = TickMath.getTickAtSqrtRatio(sqrtPriceX96Calculated);

        // Check price deviation tolerance
        int24 tolerance = int24(uint24(TOLERANCE));
        if (currentTick < currentTickCalculated - tolerance || currentTick > currentTickCalculated + tolerance) {
            revert PriceToleranceExceeded();
        }
    }

    /**
     * @notice Calculates the current ratio at which fees should be deposited in the position, swaps one token to another if needed.
     * @param currentTick The current tick of the pool.
     * @param posData A struct with variables to track for a specific position.
     * @param feeData A struct containing the accumulated fees of the position as well as the external token prices.
     * @param sqrtPriceX96 The current value of sqrtPriceX96 in the pool.
     */
    function _handleFeeRatiosForDeposit(
        int24 currentTick,
        PositionData memory posData,
        FeeData memory feeData,
        uint160 sqrtPriceX96
    ) internal {
        if (currentTick >= posData.tickUpper) {
            // Position is fully in token 1
            // Swap full amount of token0 to token1
            _swap(posData.token0, posData.token1, posData.fee, feeData.feeAmount0, sqrtPriceX96, true);
        } else if (currentTick <= posData.tickLower) {
            // Position is fully in token 0
            // Swap full amount of token1 to token0
            _swap(posData.token1, posData.token0, posData.fee, feeData.feeAmount1, sqrtPriceX96, false);
        } else {
            // Get ratio of current tick for range
            uint256 ticksInRange = uint256(int256(-posData.tickLower + posData.tickUpper));
            uint256 ticksFromCurrentToUpperTick = uint256(int256(-currentTick + posData.tickUpper));

            // Get ratio of token0/token1 based on tick ratio
            uint256 totalFee0Value = feeData.usdPriceToken0 * feeData.feeAmount0 / 1e18;
            uint256 totalFee1Value = feeData.usdPriceToken1 * feeData.feeAmount1 / 1e18;

            // Ticks in range can't be zero (upper bound should be strictly higher than lower bound for a position)
            uint256 token0Ratio = ticksFromCurrentToUpperTick * type(uint24).max / ticksInRange;
            uint256 targetToken0Value = token0Ratio * (totalFee0Value + totalFee1Value) / type(uint24).max;

            if (targetToken0Value < totalFee0Value) {
                // sell token0 to token1
                uint256 amount0ToSwap = (totalFee0Value - targetToken0Value) * feeData.feeAmount0 / totalFee0Value;
                _swap(posData.token0, posData.token1, posData.fee, amount0ToSwap, sqrtPriceX96, true);
            } else {
                // sell token1 for token0
                uint256 token1Ratio = type(uint24).max - token0Ratio;
                uint256 targetToken1Value = token1Ratio * (totalFee0Value + totalFee1Value) / type(uint24).max;
                uint256 amount1ToSwap = (totalFee1Value - targetToken1Value) * feeData.feeAmount1 / totalFee1Value;
                _swap(posData.token1, posData.token0, posData.fee, amount1ToSwap, sqrtPriceX96, false);
            }
        }
    }

    /**
     * @notice Internal function to swap one asset for another.
     * @param fromToken The address of the token to swap.
     * @param toToken The address of the token to swap to.
     * @param fee_ The fee of the pool to swap through (will be the same as the pool of the position).
     * @param amount The amount of "fromToken" to swap.
     * @param sqrtPriceX96 The current value of sqrtPriceX96 in the pool.
     * @param zeroToOne "true" if swap from token0 to token1 and "false" if from token1 to token0.
     */
    function _swap(
        address fromToken,
        address toToken,
        uint24 fee_,
        uint256 amount,
        uint160 sqrtPriceX96,
        bool zeroToOne
    ) internal {
        uint256 sqrtPriceLimitX96_ = zeroToOne
            ? sqrtPriceX96 * MAX_LOWER_SQRT_PRICE_DEVIATION / BIPS
            : sqrtPriceX96 * MAX_UPPER_SQRT_PRICE_DEVIATION / BIPS;

        ExactInputSingleParams memory exactInputParams = ExactInputSingleParams({
            tokenIn: fromToken,
            tokenOut: toToken,
            fee: fee_,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: SafeCastLib.safeCastTo160(sqrtPriceLimitX96_)
        });

        ERC20(fromToken).approve(address(SWAP_ROUTER), amount);

        SWAP_ROUTER.exactInputSingle(exactInputParams);
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

    /* 
    @notice Returns the onERC721Received selector.
    @dev Needed to receive ERC721 tokens.
    */
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
