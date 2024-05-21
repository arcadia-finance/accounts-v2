/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, ERC20Mock } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "Swap" of contract "AutoCompounder".
 */
contract Swap_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_revert_swap_ToleranceExceeded_Right() public {
        // Given : New balanced stable pool 1:1
        ERC20Mock token0;
        ERC20Mock token1;
        token0 = mockERC20.stable1;
        token1 = mockERC20.stable2;

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        uint160 sqrtPriceX96 = getSqrtPriceX96(1e18, 1e18);
        usdStablePool = createPool(token0, token1, sqrtPriceX96, 300);

        // And : Liquidity has been added for both tokens
        uint256 tokenId = addLiquidity(
            usdStablePool,
            100_000 * 10 ** mockERC20.stable1.decimals(),
            100_000 * 10 ** mockERC20.stable1.decimals(),
            users.liquidityProvider,
            -1000,
            1000
        );

        uint256 limitSqrtPriceX96 = sqrtPriceX96 * autoCompounder.MAX_UPPER_SQRT_PRICE_DEVIATION() / BIPS;

        // When : Swapping an amount that will move the price out of tolerance zone, token1 to token0
        // AmountToSwap just above tolerance
        // Then : It should revert
        uint256 amountToSwap = TOLERANCE * 102 * 10 ** mockERC20.stable1.decimals();
        mintERC20TokenTo(address(token1), address(autoCompounder), amountToSwap);
        approveERC20TokenFor(address(token1), address(usdStablePool), amountToSwap, address(autoCompounder));
        vm.expectRevert(AutoCompounder.MaxToleranceExceeded.selector);
        autoCompounder.swap(address(usdStablePool), address(token1), int256(amountToSwap), sqrtPriceX96, false);
    }

    function testFuzz_revert_swap_ToleranceExceeded_Left() public {
        // Given : New balanced stable pool 1:1
        ERC20Mock token0;
        ERC20Mock token1;
        token0 = mockERC20.stable1;
        token1 = mockERC20.stable2;

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        uint160 sqrtPriceX96 = getSqrtPriceX96(1e18, 1e18);
        usdStablePool = createPool(token0, token1, sqrtPriceX96, 300);

        // And : Liquidity has been added for both tokens
        uint256 tokenId = addLiquidity(
            usdStablePool,
            100_000 * 10 ** mockERC20.stable1.decimals(),
            100_000 * 10 ** mockERC20.stable1.decimals(),
            users.liquidityProvider,
            -1000,
            1000
        );

        uint256 limitSqrtPriceX96 = sqrtPriceX96 * autoCompounder.MAX_LOWER_SQRT_PRICE_DEVIATION() / BIPS;

        // When : Swapping an amount that will move the price out of tolerance zone, token0 to token1
        // AmountToSwap just above tolerance
        // Then : It should revert
        uint256 amountToSwap = TOLERANCE * 107 * 10 ** mockERC20.stable1.decimals();
        mintERC20TokenTo(address(token0), address(autoCompounder), amountToSwap);
        approveERC20TokenFor(address(token0), address(usdStablePool), amountToSwap, address(autoCompounder));
        vm.expectRevert(AutoCompounder.MaxToleranceExceeded.selector);
        autoCompounder.swap(address(usdStablePool), address(token0), int256(amountToSwap), sqrtPriceX96, true);
    }

    function testFuzz_success_swap_zeroToOne() public {
        // Given : New balanced stable pool 1:1
        ERC20Mock token0;
        ERC20Mock token1;
        token0 = mockERC20.stable1;
        token1 = mockERC20.stable2;

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        uint160 sqrtPriceX96 = getSqrtPriceX96(1e18, 1e18);
        usdStablePool = createPool(token0, token1, sqrtPriceX96, 300);

        // And : Liquidity has been added for both tokens
        uint256 tokenId = addLiquidity(
            usdStablePool,
            100_000 * 10 ** mockERC20.stable1.decimals(),
            100_000 * 10 ** mockERC20.stable1.decimals(),
            users.liquidityProvider,
            -1000,
            1000
        );

        uint256 limitSqrtPriceX96 = sqrtPriceX96 * autoCompounder.MAX_LOWER_SQRT_PRICE_DEVIATION() / BIPS;

        // When : Swapping an amount that will move the price out of tolerance zone, token0 to token1
        // AmountToSwap just above tolerance
        uint256 amountToSwap = TOLERANCE * 106 * 10 ** mockERC20.stable1.decimals();
        mintERC20TokenTo(address(token0), address(autoCompounder), amountToSwap);
        approveERC20TokenFor(address(token0), address(usdStablePool), amountToSwap, address(autoCompounder));
        autoCompounder.swap(address(usdStablePool), address(token0), int256(amountToSwap), sqrtPriceX96, true);

        // Then : updatedSqrtPriceX96 should be > limitSqrtPriceX96
        (uint160 updatedSqrtPriceX96,,,,,,) = usdStablePool.slot0();
        assert(updatedSqrtPriceX96 > limitSqrtPriceX96);
    }

    function testFuzz_success_swap_OneToZero() public {
        // Given : New balanced stable pool 1:1
        ERC20Mock token0;
        ERC20Mock token1;
        token0 = mockERC20.stable1;
        token1 = mockERC20.stable2;

        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        uint160 sqrtPriceX96 = getSqrtPriceX96(1e18, 1e18);
        usdStablePool = createPool(token0, token1, sqrtPriceX96, 300);

        // And : Liquidity has been added for both tokens
        uint256 tokenId = addLiquidity(
            usdStablePool,
            100_000 * 10 ** mockERC20.stable1.decimals(),
            100_000 * 10 ** mockERC20.stable1.decimals(),
            users.liquidityProvider,
            -1000,
            1000
        );

        uint256 limitSqrtPriceX96 = sqrtPriceX96 * autoCompounder.MAX_UPPER_SQRT_PRICE_DEVIATION() / BIPS;

        // When : Swapping an amount that will move the price out of tolerance zone, token0 to token1
        // AmountToSwap just above tolerance
        uint256 amountToSwap = TOLERANCE * 101 * 10 ** mockERC20.stable1.decimals();
        mintERC20TokenTo(address(token1), address(autoCompounder), amountToSwap);
        approveERC20TokenFor(address(token1), address(usdStablePool), amountToSwap, address(autoCompounder));
        autoCompounder.swap(address(usdStablePool), address(token1), int256(amountToSwap), sqrtPriceX96, false);

        // Then : updatedSqrtPriceX96 should be < limitSqrtPriceX96
        (uint160 updatedSqrtPriceX96,,,,,,) = usdStablePool.slot0();
        assert(updatedSqrtPriceX96 < limitSqrtPriceX96);
    }
}
