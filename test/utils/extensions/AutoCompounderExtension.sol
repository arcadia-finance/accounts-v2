/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder } from "../../../src/asset-managers/AutoCompounder.sol";

contract AutoCompounderExtension is AutoCompounder {
    constructor(
        address registry,
        address uniswapV3Factory,
        address nonfungiblePositionManager,
        address swapRouter,
        uint256 tolerance_,
        uint256 minUsdFeeValue,
        uint256 initiatorFee
    )
        AutoCompounder(
            registry,
            uniswapV3Factory,
            nonfungiblePositionManager,
            swapRouter,
            tolerance_,
            minUsdFeeValue,
            initiatorFee
        )
    { }

    function sqrtPriceX96InLimits(address token0, address token1, uint24 fee)
        public
        view
        returns (int24 currentTick, uint160 sqrtPriceX96, uint256 usdPriceToken0, uint256 usdPriceToken1)
    {
        (currentTick, sqrtPriceX96, usdPriceToken0, usdPriceToken1) = _sqrtPriceX96InLimits(token0, token1, fee);
    }

    function handleFeeRatiosForDeposit(
        int24 currentTick,
        PositionData memory posData,
        FeeData memory feeData,
        uint160 sqrtPriceX96
    ) public {
        _handleFeeRatiosForDeposit(currentTick, posData, feeData, sqrtPriceX96);
    }

    function swap(address fromToken, address toToken, uint24 fee, uint256 amount, uint160 sqrtPriceX96, bool zeroToOne)
        public
    {
        _swap(fromToken, toToken, fee, amount, sqrtPriceX96, zeroToOne);
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public pure returns (uint160 sqrtPriceX96) {
        sqrtPriceX96 = _getSqrtPriceX96(priceToken0, priceToken1);
    }
}
