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
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { FixedPoint96 } from "../asset-modules/UniswapV3/libraries/FixedPoint96.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IPermit2 } from "../interfaces/IPermit2.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { TickMath } from "../asset-modules/UniswapV3/libraries/TickMath.sol";
import { IUniswapV3Factory } from "./interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "./interfaces/IUniswapV3Pool.sol";

contract AutoCompounder is IActionBase {
    using FixedPointMathLib for uint256;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    IUniswapV3Factory public immutable UNI_V3_FACTORY;
    // The contract address of the Registry.
    IRegistry public immutable REGISTRY;

    address public immutable NONFUNGIBLE_POSITIONMANAGER;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InvalidERC721Amount();
    error InvalidAssetType();
    error InvalidLength();

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(address registry, address uniswapV3Factory, address nonfungiblePositionManager) {
        UNI_V3_FACTORY = IUniswapV3Factory(uniswapV3Factory);
        REGISTRY = IRegistry(registry);
        NONFUNGIBLE_POSITIONMANAGER = nonfungiblePositionManager;
    }

    /* ///////////////////////////////////////////////////////////////
                             COMPOUNDING LOGIC
    /////////////////////////////////////////////////////////////// */

    function compoundRewardsForAccount(address account, uint256 assetId) external {
        address[] memory assets_ = new address[](1);
        assets_[0] = NONFUNGIBLE_POSITIONMANAGER;
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

        bytes memory compounderData = abi.encode(assetData);
        bytes memory actionData = abi.encode(assetData, transferFromOwner, permit, signature, compounderData);
        // Trigger flashAction with actionTarget as this contract
        IAccount(account).flashAction(address(this), actionData);

        // executeAction() triggered as callback function
    }

    function executeAction(bytes calldata actionData) external override returns (ActionData memory) {
        // Position transferred from Account

        // Decode bytes data
        ActionData memory assetData = abi.decode(actionData, (ActionData));

        (,, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper,,,,,) =
            INonfungiblePositionManager(assetData.assets[0]).positions(assetData.assetIds[0]);

        // Check that sqrtPriceX96 is in limits to avoid front-running
        (int24 currentTick, uint256 usdPriceToken0, uint256 usdPriceToken1) = _sqrtPriceX96InLimits(token0, token1, fee);

        // Collect fees
        CollectParams memory collectParams = CollectParams({
            tokenId: assetData.assetIds[0],
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (uint256 feeAmount0, uint256 feeAmount1) =
            INonfungiblePositionManager(assetData.assets[0]).collect(collectParams);

        // Get amounts to deposit for current range of position
        _handleFeeRatiosForDeposit(
            currentTick, tickLower, tickUpper, feeAmount0, feeAmount1, token0, token1, usdPriceToken0, usdPriceToken1
        );

        // Increase liquidity in pool
        IncreaseLiquidityParams memory increaseLiquidityParams = IncreaseLiquidityParams({
            tokenId: assetData.assetIds[0],
            amount0Desired: IERC20(token0).balanceOf(address(this)),
            amount1Desired: IERC20(token1).balanceOf(address(this)),
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        INonfungiblePositionManager(assetData.assets[0]).increaseLiquidity(increaseLiquidityParams);

        // Transfer excess tokens to Account (deposit ?)
        // TODO: or we deposit by passing the excess amounts in assetData (depositData) returned to Account (gas+)
        // TODO: or we send assets to the Account without depositing

        // Deposit position back to account
        return assetData;
    }

    function _sqrtPriceX96InLimits(address token0, address token1, uint24 fee)
        internal
        returns (int24 currentTick, uint256 usdPriceToken0, uint256 usdPriceToken1)
    {
        // Get sqrtPriceX96 from pool
        address pool = UNI_V3_FACTORY.getPool(token0, token1, fee);
        (uint160 sqrtPriceX96, int24 currentTick_,,,,,) = IUniswapV3Pool(pool).slot0();
        currentTick = currentTick_;

        // Get current prices
        address[] memory assets = new address[](2);
        uint256[] memory assetIds = new uint256[](2);
        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 0;
        assetAmounts[1] = 1;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            REGISTRY.getValuesInUsd(address(0), assets, assetIds, assetAmounts);

        // Recalculate sqrtPriceX96 based on external prices
        uint256 sqrtPriceX96Calculated =
            _getSqrtPriceX96(valuesAndRiskFactors[0].assetValue, valuesAndRiskFactors[1].assetValue);

        // TODO : compare ratio of sqrtPriceX96Calculated to sqrtPriceX96 and see if in limits.
    }

    function _handleFeeRatiosForDeposit(
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper,
        uint256 feeAmount0,
        uint256 feeAmount1,
        address token0,
        address token1,
        uint256 priceToken0,
        uint256 priceToken1
    ) internal {
        if (currentTick >= tickUpper) {
            // Position is fully in token 1
            // Swap full amount of token0 to token1
            _swap(token0, token1, feeAmount0);
        } else if (currentTick <= tickLower) {
            // Position is fully in token 0
            // Swap full amount of token1 to token0
            _swap(token1, token0, feeAmount1);
        } else {
            // Get ratio of current tick for range
            uint256 ticksInRange = uint256(int256(-tickLower + tickUpper));
            uint256 ticksFromCurrentToUpperTick = uint256(int256(-currentTick + tickUpper));

            // Get ratio of token0/token1 based on tick ratio
            uint256 totalFee0Value = priceToken0 * feeAmount0;
            uint256 totalFee1Value = priceToken1 * feeAmount1;
            uint256 totalFeeValue = totalFee0Value + totalFee1Value;

            uint256 token0Ratio = ticksFromCurrentToUpperTick * type(uint24).max / (ticksInRange + 1);
            uint256 targetToken0Value = token0Ratio * totalFeeValue / type(uint24).max;

            if (targetToken0Value < totalFee0Value) {
                // sell token0 to token1
                uint256 amount0ToSwap = (totalFee0Value - targetToken0Value) * feeAmount0 / totalFee0Value;
                _swap(token0, token1, amount0ToSwap);
            } else {
                // sell token1 for token0
                uint256 token1Ratio = type(uint24).max - token0Ratio;
                uint256 targetToken1Value = token1Ratio * totalFeeValue / type(uint24).max;
                uint256 amount1ToSwap = (totalFee1Value - targetToken1Value) * feeAmount1 / totalFee1Value;
                _swap(token1, token0, amount1ToSwap);
            }
        }
    }

    // TODO : to implement
    function _swap(address fromToken, address toToken, uint256 amount) internal { }

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

    /*
    @notice Returns the onERC1155Received selector.
    @dev Needed to receive ERC1155 tokens.
    */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
