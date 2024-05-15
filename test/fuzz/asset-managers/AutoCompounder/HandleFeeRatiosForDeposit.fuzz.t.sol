/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, ERC20Mock } from "./_AutoCompounder.fuzz.t.sol";

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

        // And : currentTick = tickUpper
        int24 currentTick = testVars.tickUpper;

        // Deposit feeAmount0 at currentTick range (to enable swap)
        addLiquidity(
            usdStablePool,
            testVars.feeAmount0 * 10 ** token0.decimals(),
            testVars.feeAmount1 * 10 ** token1.decimals(),
            users.liquidityProvider,
            currentTick - 10,
            currentTick + 10
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
            feeAmount0: testVars.feeAmount0,
            feeAmount1: testVars.feeAmount1
        });

        // And : Mint fees to AutoCompounder
        ERC20Mock(address(token0)).mint(address(autoCompounder), testVars.feeAmount0);

        assert(token0.balanceOf(address(autoCompounder)) > 0);

        // Given : sqrtPriceX96 set to zero below as we will test max slippage for swap function separately
        // When : calling handleFeeRatiosForDeposit()
        autoCompounder.handleFeeRatiosForDeposit(currentTick, posData, feeData, 0);

        // Then : feeAmount0 should have been swapped to token1
        assertEq(token0.balanceOf(address(autoCompounder)), 0);
    }

    function testFuzz_success_currentTickSmallerOrEqualToTickUpper(TestVariables memory testVars) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        // And : currentTick = tickUpper
        int24 currentTick = testVars.tickLower;

        // Deposit feeAmount1 at currentTick range (to enable swap)
        addLiquidity(
            usdStablePool,
            testVars.feeAmount0 * 10 ** token0.decimals(),
            testVars.feeAmount1 * 10 ** token1.decimals(),
            users.liquidityProvider,
            currentTick - 10,
            currentTick + 10
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
            feeAmount0: testVars.feeAmount0,
            feeAmount1: testVars.feeAmount1
        });

        // And : Mint fees to AutoCompounder
        ERC20Mock(address(token1)).mint(address(autoCompounder), testVars.feeAmount1);

        assert(token1.balanceOf(address(autoCompounder)) > 0);

        // Given : sqrtPriceX96 set to zero below as we will test max slippage for swap function separately
        // When : calling handleFeeRatiosForDeposit()
        autoCompounder.handleFeeRatiosForDeposit(currentTick, posData, feeData, 0);

        // Then : feeAmount1 should have been swapped to token0
        assertEq(token1.balanceOf(address(autoCompounder)), 0);
    }

    function testFuzz_success_tickInRangeWithExcessToken0Fees(TestVariables memory testVars) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

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
        autoCompounder.handleFeeRatiosForDeposit(usdStablePool.getCurrentTick(), posData, feeData, 0);

        // Then : part of feeAmount0 should have been swapped to token1
        assert(token0.balanceOf(address(autoCompounder)) < testVars.feeAmount0 * 10 ** token0.decimals());

        // And : In order to test the proportions, we will validate that dust amount is minimal when calling executeAction()
    }

    function testFuzz_success_tickInRangeWithExcessToken1Fees(TestVariables memory testVars) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

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
        autoCompounder.handleFeeRatiosForDeposit(usdStablePool.getCurrentTick(), posData, feeData, 0);

        // Then : part of feeAmount1 should have been swapped to token1
        assert(token1.balanceOf(address(autoCompounder)) < testVars.feeAmount1 * 10 ** token1.decimals());

        // And : In order to test the proportions, we will validate that dust amount is minimal when calling executeAction()
    }
}
