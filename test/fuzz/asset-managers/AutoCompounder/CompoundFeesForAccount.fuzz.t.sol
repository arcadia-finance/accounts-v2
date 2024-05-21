/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, ISwapRouter02 } from "./_AutoCompounder.fuzz.t.sol";
import { ERC721 } from "../../../utils/mocks/tokens/ERC721Mock.sol";

/**
 * @notice Fuzz tests for the function "CompoundFeesForAccount" of contract "AutoCompounder".
 */
contract CompoundFeesForAccount_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_compoundFeesForAccount_FeeAmountTooLow(TestVariables memory testVars, address initiator)
        public
    {
        // Given : Valid state
        (testVars,) = givenValidBalancedState(testVars);

        // And : Fee amounts are too low
        testVars.feeAmount0 = ((MIN_USD_FEES_VALUE / 2e18) - 1);
        testVars.feeAmount1 = ((MIN_USD_FEES_VALUE / 2e18) - 1);

        // And : State is persisted
        uint256 tokenId = setState(testVars, usdStablePool);

        // And : Transfer position to account owner
        vm.prank(users.liquidityProvider);
        ERC721(address(nonfungiblePositionManager)).transferFrom(users.liquidityProvider, users.accountOwner, tokenId);

        // And : Deploy uniswapV3AM
        deployUniswapV3AM(address(nonfungiblePositionManager));

        {
            address[] memory assets_ = new address[](1);
            assets_[0] = address(nonfungiblePositionManager);
            uint256[] memory assetIds_ = new uint256[](1);
            assetIds_[0] = tokenId;
            uint256[] memory assetAmounts_ = new uint256[](1);
            assetAmounts_[0] = 1;

            // And : Deposit position in Account
            vm.startPrank(users.accountOwner);
            ERC721(address(nonfungiblePositionManager)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assets_, assetIds_, assetAmounts_);
            vm.stopPrank();
        }

        // And : AutoCompounder is allowed as Asset Manager
        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(autoCompounder), true);

        // When : Calling compoundFeesForAccount()
        vm.startPrank(initiator);
        vm.expectRevert(AutoCompounder.FeeValueBelowTreshold.selector);
        autoCompounder.compoundFeesForAccount(address(proxyAccount), tokenId);
        vm.stopPrank();
    }

    function testFuzz_Success_compoundFeesForAccount(TestVariables memory testVars, address initiator) public {
        // Given : Valid state
        (testVars,) = givenValidBalancedState(testVars);

        // And : State is persisted
        uint256 tokenId = setState(testVars, usdStablePool);

        // And : Transfer position to account owner
        vm.prank(users.liquidityProvider);
        ERC721(address(nonfungiblePositionManager)).transferFrom(users.liquidityProvider, users.accountOwner, tokenId);

        // And : Deploy uniswapV3AM
        deployUniswapV3AM(address(nonfungiblePositionManager));

        {
            address[] memory assets_ = new address[](1);
            assets_[0] = address(nonfungiblePositionManager);
            uint256[] memory assetIds_ = new uint256[](1);
            assetIds_[0] = tokenId;
            uint256[] memory assetAmounts_ = new uint256[](1);
            assetAmounts_[0] = 1;

            // And : Deposit position in Account
            vm.startPrank(users.accountOwner);
            ERC721(address(nonfungiblePositionManager)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assets_, assetIds_, assetAmounts_);
            vm.stopPrank();
        }

        // And : AutoCompounder is allowed as Asset Manager
        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(autoCompounder), true);

        // Check liquidity pre-compounding
        (,,,,,,, uint128 initialLiquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        // When : Calling compoundFeesForAccount()
        vm.prank(initiator);
        autoCompounder.compoundFeesForAccount(address(proxyAccount), tokenId);

        // Then : Liquidity of position should have increased
        (,,,,,,, uint128 newLiquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        assertGt(newLiquidity, initialLiquidity);

        uint256 initiatorFeesToken0 = token0.balanceOf(initiator);
        uint256 initiatorFeesToken1 = token1.balanceOf(initiator);

        uint256 totalFee0 = (testVars.feeAmount0 * 10 ** token0.decimals());
        uint256 totalFee1 = (testVars.feeAmount1 * 10 ** token1.decimals());

        uint256 initiatorFeeToken0Calculated = totalFee0 * INITIATOR_FEE / BIPS;
        uint256 initiatorFeeToken1Calculated = (totalFee1 * INITIATOR_FEE / BIPS);

        // And : initiatorFees should be correct. We add 1 for rounding issues in contract
        assert(initiatorFeesToken0 + 1 >= initiatorFeeToken0Calculated);
        assert(initiatorFeesToken1 + 1 >= initiatorFeeToken1Calculated);
    }

    function testFuzz_Success_compoundFeesForAccount_MoveTickRight(TestVariables memory testVars, address initiator)
        public
    {
        // Given : Valid state
        (testVars,) = givenValidBalancedState(testVars);

        // And : State is persisted
        uint256 tokenId = setState(testVars, usdStablePool);

        // And : Transfer position to account owner
        vm.prank(users.liquidityProvider);
        ERC721(address(nonfungiblePositionManager)).transferFrom(users.liquidityProvider, users.accountOwner, tokenId);

        // And : Deploy uniswapV3AM
        deployUniswapV3AM(address(nonfungiblePositionManager));

        {
            address[] memory assets_ = new address[](1);
            assets_[0] = address(nonfungiblePositionManager);
            uint256[] memory assetIds_ = new uint256[](1);
            assetIds_[0] = tokenId;
            uint256[] memory assetAmounts_ = new uint256[](1);
            assetAmounts_[0] = 1;

            // And : Deposit position in Account
            vm.startPrank(users.accountOwner);
            ERC721(address(nonfungiblePositionManager)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assets_, assetIds_, assetAmounts_);
            vm.stopPrank();
        }

        // And : AutoCompounder is allowed as Asset Manager
        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(autoCompounder), true);

        // And : Move tick right
        uint256 amount1ToSwap;
        {
            // Swap max amount to move ticks left (ensure tolerance is not exceeded when compounding afterwards)
            amount1ToSwap = 100_000_000_000_000 * 10 ** token1.decimals();

            mintERC20TokenTo(address(token1), users.swapper, amount1ToSwap);

            vm.startPrank(users.swapper);
            token1.approve(address(swapRouter), amount1ToSwap);

            ISwapRouter02.ExactInputSingleParams memory exactInputParams = ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(token1),
                tokenOut: address(token0),
                fee: POOL_FEE,
                recipient: users.swapper,
                amountIn: amount1ToSwap,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            swapRouter.exactInputSingle(exactInputParams);

            vm.stopPrank();
        }

        // Check liquidity pre-compounding
        (,,,,,,, uint128 initialLiquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        // When : Calling compoundFeesForAccount()
        vm.prank(initiator);
        autoCompounder.compoundFeesForAccount(address(proxyAccount), tokenId);

        // Then : Liquidity of position should have increased
        (,,,,,,, uint128 newLiquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        assertGt(newLiquidity, initialLiquidity);

        // And : Initiator fees should have been distributed
        uint256 initiatorFeesToken0 = token0.balanceOf(initiator);
        uint256 initiatorFeesToken1 = token1.balanceOf(initiator);

        uint256 totalFee0 = (testVars.feeAmount0 * 10 ** token0.decimals());
        uint256 totalFee1 = (testVars.feeAmount1 * 10 ** token1.decimals()) + (amount1ToSwap * 1 / BIPS);

        uint256 initiatorFeeToken0Calculated = totalFee0 * INITIATOR_FEE / BIPS;
        uint256 initiatorFeeToken1Calculated = totalFee1 * INITIATOR_FEE / BIPS;

        assert(initiatorFeesToken0 + 1 >= initiatorFeeToken0Calculated);
        assert(initiatorFeesToken1 + 1 >= initiatorFeeToken1Calculated);

        if (token0.decimals() < token1.decimals()) {
            uint256 dustToken0InUsdValue = ((initiatorFeesToken0 + 1) - initiatorFeeToken0Calculated) * 1e30 / 1e18;
            uint256 dustToken1InUsdValue = ((initiatorFeesToken1 + 1) - initiatorFeeToken1Calculated) * 1e18 / 1e18;

            uint256 totalFee0InUsd = totalFee0 * 1e30 / 1e18;
            uint256 totalFee1InUsd = totalFee1 * 1e18 / 1e18;

            // Ensure dust represents max 3% from fees (is dependent on tolerance and tick range)
            // We keep relatively high tolerance as otherwise we are not able to move the tick enough
            // Dust amount decreases when lower tolerance
            assert(dustToken0InUsdValue + dustToken1InUsdValue < 300 * (totalFee0InUsd + totalFee1InUsd) / 10_000);
        } else {
            uint256 dustToken0InUsdValue = ((initiatorFeesToken0 + 1) - initiatorFeeToken0Calculated) * 1e18 / 1e18;
            uint256 dustToken1InUsdValue = ((initiatorFeesToken1 + 1) - initiatorFeeToken1Calculated) * 1e30 / 1e18;

            uint256 totalFee0InUsd = totalFee0 * 1e18 / 1e18;
            uint256 totalFee1InUsd = totalFee1 * 1e30 / 1e18;

            // Ensure dust represents max 3% from fees (is dependent on tolerance and tick range)
            // We keep relatively high tolerance as otherwise we are not able to move the tick enough
            // Dust amount decreases when lower tolerance
            assert(dustToken0InUsdValue + dustToken1InUsdValue < 300 * (totalFee0InUsd + totalFee1InUsd) / 10_000);
        }
    }

    function testFuzz_Success_compoundFeesForAccount_MoveTickLeft(TestVariables memory testVars, address initiator)
        public
    {
        // Given : Valid state
        (testVars,) = givenValidBalancedState(testVars);

        // And : State is persisted
        uint256 tokenId = setState(testVars, usdStablePool);

        // And : Transfer position to account owner
        vm.prank(users.liquidityProvider);
        ERC721(address(nonfungiblePositionManager)).transferFrom(users.liquidityProvider, users.accountOwner, tokenId);

        // And : Deploy uniswapV3AM
        deployUniswapV3AM(address(nonfungiblePositionManager));

        {
            address[] memory assets_ = new address[](1);
            assets_[0] = address(nonfungiblePositionManager);
            uint256[] memory assetIds_ = new uint256[](1);
            assetIds_[0] = tokenId;
            uint256[] memory assetAmounts_ = new uint256[](1);
            assetAmounts_[0] = 1;

            // And : Deposit position in Account
            vm.startPrank(users.accountOwner);
            ERC721(address(nonfungiblePositionManager)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assets_, assetIds_, assetAmounts_);
            vm.stopPrank();
        }

        // And : AutoCompounder is allowed as Asset Manager
        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(autoCompounder), true);

        // And : Move tick right
        uint256 amount0ToSwap;
        {
            // Swap max amount to move ticks right (ensure tolerance is not exceeded when compounding afterwards)
            amount0ToSwap = 100_000_000_000_000 * 10 ** token0.decimals();

            mintERC20TokenTo(address(token0), users.swapper, amount0ToSwap);

            vm.startPrank(users.swapper);
            token0.approve(address(swapRouter), amount0ToSwap);

            ISwapRouter02.ExactInputSingleParams memory exactInputParams = ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                fee: POOL_FEE,
                recipient: users.swapper,
                amountIn: amount0ToSwap,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            swapRouter.exactInputSingle(exactInputParams);

            vm.stopPrank();
        }

        // Check liquidity pre-compounding
        (,,,,,,, uint128 initialLiquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        // When : Calling compoundFeesForAccount()
        vm.prank(initiator);
        autoCompounder.compoundFeesForAccount(address(proxyAccount), tokenId);

        // Then : Liquidity of position should have increased
        (,,,,,,, uint128 newLiquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        assertGt(newLiquidity, initialLiquidity);

        // And : Initiator fees should have been distributed
        uint256 initiatorFeesToken0 = token0.balanceOf(initiator);
        uint256 initiatorFeesToken1 = token1.balanceOf(initiator);

        uint256 totalFee0 = (testVars.feeAmount0 * 10 ** token0.decimals()) + (amount0ToSwap * 1 / BIPS);
        uint256 totalFee1 = (testVars.feeAmount1 * 10 ** token1.decimals());

        uint256 initiatorFeeToken0Calculated = totalFee0 * INITIATOR_FEE / BIPS;
        uint256 initiatorFeeToken1Calculated = (totalFee1 * INITIATOR_FEE / BIPS);

        assert(initiatorFeesToken0 + 1 >= initiatorFeeToken0Calculated);
        assert(initiatorFeesToken1 + 1 >= initiatorFeeToken1Calculated);

        if (token0.decimals() < token1.decimals()) {
            uint256 dustToken0InUsdValue = (initiatorFeesToken0 - initiatorFeeToken0Calculated) * 1e30 / 1e18;
            uint256 dustToken1InUsdValue = (initiatorFeesToken1 + 1 - initiatorFeeToken1Calculated) * 1e18 / 1e18;

            uint256 totalFee0InUsd = totalFee0 * 1e30 / 1e18;
            uint256 totalFee1InUsd = totalFee1 * 1e18 / 1e18;

            // Ensure dust represents max 3% from fees (is dependent on tolerance and tick range)
            // We keep relatively high tolerance as otherwise we are not able to move the tick enough
            // Dust amount decreases when lower tolerance
            assert(dustToken0InUsdValue + dustToken1InUsdValue < 300 * (totalFee0InUsd + totalFee1InUsd) / 10_000);
        } else {
            uint256 dustToken0InUsdValue = (initiatorFeesToken0 - initiatorFeeToken0Calculated) * 1e18 / 1e18;
            uint256 dustToken1InUsdValue = (initiatorFeesToken1 + 1 - initiatorFeeToken1Calculated) * 1e30 / 1e18;

            uint256 totalFee0InUsd = totalFee0 * 1e18 / 1e18;
            uint256 totalFee1InUsd = totalFee1 * 1e30 / 1e18;

            // Ensure dust represents max 2% from fees (is dependent on tolerance and tick range)
            // We keep relatively high tolerance as otherwise we are not able to move the tick enough
            // Dust amount decreases when lower tolerance
            assert(dustToken0InUsdValue + dustToken1InUsdValue < 300 * (totalFee0InUsd + totalFee1InUsd) / 10_000);
        }
    }
}
