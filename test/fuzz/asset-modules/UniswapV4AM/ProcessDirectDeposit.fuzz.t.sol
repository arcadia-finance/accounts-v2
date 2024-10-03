/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV4/libraries/LiquidityAmountsV4.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AM } from "../../../../src/asset-modules/UniswapV4/UniswapV4AM.sol";
import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "UniswapV4AM".
 */
contract ProcessDirectDeposit_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();

        token0 = new ERC20Mock("Token 0", "TOK0", 18);
        token1 = new ERC20Mock("Token 1", "TOK1", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(
        address creditor,
        address unprivilegedAddress,
        uint256 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        vm.assume(unprivilegedAddress != address(registry));

        // Given : Valid state
        (uint256 tokenId,,,) = givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        uniswapV4AM.processDirectDeposit(creditor, address(positionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ZeroLiquidity(
        address creditor,
        int24 tickLower,
        int24 tickUpper,
        uint96 tokenId
    ) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Position is set (with 0 liquidity)
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When : Calling processDirectDeposit()
        // Then : It should revert
        vm.startPrank(address(registry));
        vm.expectRevert(UniswapV4AM.ZeroLiquidity.selector);
        uniswapV4AM.processDirectDeposit(creditor, address(positionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ExposureToken0ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 maxExposure0
    ) public {
        // Given : Valid state, with position fully in token0 (amount0 needed in this test case)
        (uint256 tokenId, uint256 amount0,,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 2);

        // And : Condition on which the call should revert: exposure to token0 becomes bigger than maxExposure0.
        vm.assume(amount0 > 0);
        vm.assume(amount0 < type(uint112).max);
        initialExposure0 = uint112(bound(initialExposure0, 0, amount0 - 1));
        maxExposure0 = uint112(bound(maxExposure0, initialExposure0 + 1, initialExposure0 + amount0));

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(priceToken0), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(priceToken1));

        // When : Calling processDirectDeposit()
        // Then : It should revert
        vm.startPrank(address(registry));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ExposureToken1ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure1,
        uint112 maxExposure1
    ) public {
        // Given : Valid state, with position fully in token0 (amount0 needed in this test case)
        (uint256 tokenId,, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 1);

        // Condition on which the call should revert: exposure to token1 becomes bigger than maxExposure1.
        vm.assume(amount1 > 0);
        vm.assume(amount1 < type(uint112).max);
        initialExposure1 = uint112(bound(initialExposure1, 0, amount1 - 1));
        maxExposure1 = uint112(bound(maxExposure1, initialExposure1 + 1, initialExposure1 + amount1));

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(priceToken0), 0, type(uint112).max);
        addAssetToArcadia(address(token1), int256(priceToken1), initialExposure1, maxExposure1);

        vm.startPrank(address(registry));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_UsdExposureProtocolExceedsMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given : Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // Check that exposure to underlying tokens stays below maxExposures.
        // vm.assume(amount0 + initialExposure0 < maxExposure0);
        // vm.assume(amount1 + initialExposure1 < maxExposure1);
        initialExposure0 = uint112(bound(initialExposure0, 0, maxExposure0 + amount0));
        initialExposure1 = uint112(bound(initialExposure1, 0, maxExposure1 + amount1));

        // And: Usd value of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 < type(uint112).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 < type(uint112).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, 0, usdExposureProtocol));
        }

        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100);

        vm.startPrank(address(registry));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit_DepositAmountOne(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given : Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // And : Exposure to underlying tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 < maxExposure0);
        vm.assume(amount1 + initialExposure1 < maxExposure1);

        // And: Usd value of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100);

        {
            // When: processDirectDeposit is called with amount 1.
            vm.prank(address(registry));
            uint256 recursiveCalls =
                uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);

            // Then: Correct variables are returned.
            assertEq(recursiveCalls, 3);
        }

        // And: Exposure of the asset is one.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManager)));
        (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
        assertEq(lastExposureAsset, 1);

        // And: Exposures to the underlying assets are updated.
        // Token0:
        bytes32 underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
        assertEq(
            uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
            amount0
        );
        (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
        assertEq(exposure, amount0 + initialExposure0);
        // Token1:
        underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
        assertEq(
            uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
            amount1
        );
        (exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
        assertEq(exposure, amount1 + initialExposure1);
    }

    function testFuzz_Success_processDirectDeposit_DepositAmountZero_BeforeDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given : Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // Check that exposure to underlying tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 < maxExposure0);
        vm.assume(amount1 + initialExposure1 < maxExposure1);

        // And: Usd value of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100);

        {
            // When: processDirectDeposit is called with amount 0.
            vm.prank(address(registry));
            uint256 recursiveCalls =
                uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 0);

            // Then: Correct variables are returned.
            assertEq(recursiveCalls, 3);
        }

        {
            // And: Exposure of the asset is one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManager)));
            (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 0);

            // And: Exposures to the underlying assets are updated.
            // Token0:
            bytes32 underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                0
            );
            (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, initialExposure0);
            // Token1:
            underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                0
            );
            (exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, initialExposure1);
        }
    }

    function testFuzz_Success_processDirectDeposit_DepositAmountZero_AfterDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given : Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1, bytes32 positionKey) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // Check that exposure to underlying tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 < maxExposure0);
        vm.assume(amount1 + initialExposure1 < maxExposure1);

        // And: Usd value of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100);

        // Given: uniV4 position is deposited.
        vm.prank(address(registry));
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);

        {
            // And: liquidity of the deposited position is increased.
            uint128 currentLiquidity = stateView.getPositionLiquidity(randomPoolKey.toId(), positionKey);
            poolManager.setPositionLiquidity(randomPoolKey.toId(), positionKey, currentLiquidity + 1e18);

            // When: processDirectDeposit is called with amount 0.
            vm.prank(address(registry));
            uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 0);

            // Then: Exposure of the asset is still one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManager)));
            (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);

            // And: Exposures to the underlying assets are of the old liquidity.
            // Token0:
            bytes32 underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                amount0
            );
            (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, amount0 + initialExposure0);
            // Token1:
            underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                amount1
            );
            (exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, amount1 + initialExposure1);
        }
    }
}