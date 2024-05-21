/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, ERC20Mock, TickMath } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "handleFeeRatiosForDeposit" of contract "AutoCompounder".
 */
contract HandleFeeRatiosForDeposit_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_success_currentTickGreaterOrEqualToTickUpper(TestVariables memory testVars) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        // And : newTick = tickLower
        int24 newTick = testVars.tickUpper;
        usdStablePool.setCurrentTick(newTick);

        // And : Update sqrtPriceX96 in slot0
        uint160 sqrtPriceX96AtCurrentTick = TickMath.getSqrtRatioAtTick(newTick);
        usdStablePool.setSqrtPriceX96(sqrtPriceX96AtCurrentTick);

        // Deposit feeAmount0 at currentTick range (to enable swap)
        addLiquidity(
            usdStablePool,
            token0HasLowestDecimals
                ? type(uint32).max * 10 ** token0.decimals()
                : type(uint24).max * 10 ** token0.decimals(),
            token0HasLowestDecimals
                ? type(uint24).max * 10 ** token0.decimals()
                : type(uint32).max * 10 ** token0.decimals(),
            users.liquidityProvider,
            newTick - 20,
            newTick + 20
        );

        AutoCompounder.PositionData memory posData = AutoCompounder.PositionData({
            token0: address(token0),
            token1: address(token1),
            fee: 100,
            tickLower: testVars.tickLower,
            tickUpper: testVars.tickUpper
        });

        (uint256 usdPriceToken0, uint256 usdPriceToken1) = getPrices();

        AutoCompounder.FeeData memory feeData = AutoCompounder.FeeData({
            usdPriceToken0: usdPriceToken0,
            usdPriceToken1: usdPriceToken1,
            feeAmount0: testVars.feeAmount0 * 10 ** token0.decimals(),
            feeAmount1: testVars.feeAmount1 * 10 ** token1.decimals()
        });

        // And : Mint fees to AutoCompounder
        ERC20Mock(address(token0)).mint(address(autoCompounder), testVars.feeAmount0 * 10 ** token0.decimals());

        assert(token0.balanceOf(address(autoCompounder)) > 0);

        // Given : sqrtPriceX96 set to zero below as we will test max slippage for swap function separately
        // When : calling handleFeeRatiosForDeposit()
        autoCompounder.handleFeeRatiosForDeposit(
            address(usdStablePool), newTick, posData, feeData, sqrtPriceX96AtCurrentTick
        );

        // Then : feeAmount0 should have been swapped to token1
        assertEq(token0.balanceOf(address(autoCompounder)), 0);
    }

    function testFuzz_success_currentTickSmallerOrEqualToTickLower(TestVariables memory testVars) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        // And : newTick = tickLower
        int24 newTick = testVars.tickLower;
        usdStablePool.setCurrentTick(newTick);

        // And : Update sqrtPriceX96 in slot0
        uint160 sqrtPriceX96AtCurrentTick = TickMath.getSqrtRatioAtTick(newTick);
        usdStablePool.setSqrtPriceX96(sqrtPriceX96AtCurrentTick);

        // Deposit feeAmount1 at currentTick range (to enable swap)
        addLiquidity(
            usdStablePool,
            token0HasLowestDecimals
                ? type(uint32).max * 10 ** token0.decimals()
                : type(uint24).max * 10 ** token0.decimals(),
            token0HasLowestDecimals
                ? type(uint24).max * 10 ** token0.decimals()
                : type(uint32).max * 10 ** token0.decimals(),
            users.liquidityProvider,
            newTick - 20,
            newTick + 20
        );

        AutoCompounder.PositionData memory posData = AutoCompounder.PositionData({
            token0: address(token0),
            token1: address(token1),
            fee: 100,
            tickLower: testVars.tickLower,
            tickUpper: testVars.tickUpper
        });

        (uint256 usdPriceToken0, uint256 usdPriceToken1) = getPrices();

        AutoCompounder.FeeData memory feeData = AutoCompounder.FeeData({
            usdPriceToken0: usdPriceToken0,
            usdPriceToken1: usdPriceToken1,
            feeAmount0: testVars.feeAmount0 * 10 ** token0.decimals(),
            feeAmount1: testVars.feeAmount1 * 10 ** token1.decimals()
        });

        // And : Mint fees to AutoCompounder
        ERC20Mock(address(token1)).mint(address(autoCompounder), testVars.feeAmount1 * 10 ** token1.decimals());

        assert(token1.balanceOf(address(autoCompounder)) > 0);

        // Given : sqrtPriceX96 set to zero below as we will test max slippage for swap function separately
        // When : calling handleFeeRatiosForDeposit()
        autoCompounder.handleFeeRatiosForDeposit(
            address(usdStablePool), newTick, posData, feeData, sqrtPriceX96AtCurrentTick
        );

        // Then : feeAmount1 should have been swapped to token0
        assertEq(token1.balanceOf(address(autoCompounder)), 0);
    }

    function testFuzz_success_tickInRangeWithExcessToken0Fees(TestVariables memory testVars) public {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : totalFee0 is greater than totalFee1
        // And : currentTick unchanged (50/50)
        // Case for targetToken0Value < totalFee0Value
        vm.assume(testVars.feeAmount0 > testVars.feeAmount1);

        // And : State is persisted
        setState(testVars, usdStablePool);

        AutoCompounder.PositionData memory posData = AutoCompounder.PositionData({
            token0: address(token0),
            token1: address(token1),
            fee: 100,
            tickLower: testVars.tickLower,
            tickUpper: testVars.tickUpper
        });

        (uint256 usdPriceToken0, uint256 usdPriceToken1) = getPrices();

        AutoCompounder.FeeData memory feeData = AutoCompounder.FeeData({
            usdPriceToken0: usdPriceToken0,
            usdPriceToken1: usdPriceToken1,
            feeAmount0: testVars.feeAmount0 * 10 ** token0.decimals(),
            feeAmount1: testVars.feeAmount1 * 10 ** token1.decimals()
        });

        // And : Mint fees to AutoCompounder
        ERC20Mock(address(token0)).mint(address(autoCompounder), testVars.feeAmount0 * 10 ** token0.decimals());

        assert(token0.balanceOf(address(autoCompounder)) > 0);

        // Given : sqrtPriceX96 set to zero below as we will test max slippage for swap function separately
        // When : calling handleFeeRatiosForDeposit()
        (uint160 sqrtPriceX96,,,,,,) = usdStablePool.slot0();
        autoCompounder.handleFeeRatiosForDeposit(
            address(usdStablePool), usdStablePool.getCurrentTick(), posData, feeData, sqrtPriceX96
        );

        // Then : part of feeAmount0 should have been swapped to token1
        assert(token0.balanceOf(address(autoCompounder)) < testVars.feeAmount0 * 10 ** token0.decimals());

        // And : In order to test the proportions, we will validate that dust amount is minimal when calling executeAction()
    }

    function testFuzz_success_tickInRangeWithExcessToken1Fees(TestVariables memory testVars) public {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : totalFee1 is greater than totalFee0
        // And : currentTick unchanged (50/50)
        // Case for targetToken0Value <= totalFee0Value
        vm.assume(testVars.feeAmount1 > uint256(testVars.feeAmount0));

        // And : State is persisted
        setState(testVars, usdStablePool);

        AutoCompounder.PositionData memory posData = AutoCompounder.PositionData({
            token0: address(token0),
            token1: address(token1),
            fee: 100,
            tickLower: testVars.tickLower,
            tickUpper: testVars.tickUpper
        });

        (uint256 usdPriceToken0, uint256 usdPriceToken1) = getPrices();

        AutoCompounder.FeeData memory feeData = AutoCompounder.FeeData({
            usdPriceToken0: usdPriceToken0,
            usdPriceToken1: usdPriceToken1,
            feeAmount0: testVars.feeAmount0 * 10 ** token0.decimals(),
            feeAmount1: testVars.feeAmount1 * 10 ** token1.decimals()
        });

        // And : Mint fees to AutoCompounder
        ERC20Mock(address(token1)).mint(address(autoCompounder), testVars.feeAmount1 * 10 ** token1.decimals());

        assert(token1.balanceOf(address(autoCompounder)) > 0);

        // Given : sqrtPriceX96 set to zero below as we will test max slippage for swap function separately
        // When : calling handleFeeRatiosForDeposit()
        (uint160 sqrtPriceX96,,,,,,) = usdStablePool.slot0();
        autoCompounder.handleFeeRatiosForDeposit(
            address(usdStablePool), usdStablePool.getCurrentTick(), posData, feeData, sqrtPriceX96
        );

        // Then : part of feeAmount1 should have been swapped to token1
        assert(token1.balanceOf(address(autoCompounder)) < testVars.feeAmount1 * 10 ** token1.decimals());

        // And : In order to test the proportions, we will validate that dust amount is minimal when calling executeAction()
    }
}
