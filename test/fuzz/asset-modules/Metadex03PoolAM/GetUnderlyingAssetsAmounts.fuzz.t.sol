/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Metadex03PoolAM_Fuzz_Test, FixedPointMathLib, FullMath, ERC20Mock } from "./_Metadex03PoolAM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "Metadex03PoolAM".
 */
contract GetUnderlyingAssetsAmounts_Metadex03PoolAM_Fuzz_Test is Metadex03PoolAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03PoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Volatile_OverflowReserve0(TestVariables memory testVars)
        public
    {
        // Given: The pool is volatile with two tokens of supported decimals.
        testVars.stable = false;
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And: The usd rates of both tokens do not overflow in "_getRateUnderlyingAssetsToUsd".
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Both reserves are non zero and their product, the invariant k, does not overflow.
        vm.assume(testVars.reserve0 != 0);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;

        // And: The first mint yields at least the minimum liquidity the pool requires.
        vm.assume(FixedPointMathLib.sqrt(k) >= 2 * MINIMUM_LIQUIDITY);

        // And: The usd value of the pool exceeds uint256, so the trusted reserve of token0 overflows.
        vm.assume(k / p0 > type(uint256).max / p1);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        // Then: It reverts, the trusted reserve of token0 overflows.
        vm.expectRevert(bytes(""));
        metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Volatile_OverflowUnderlyingAssetAmount0(TestVariables memory testVars)
        public
    {
        // Given: The pool is volatile with two tokens of supported decimals.
        testVars.stable = false;
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And: The usd rates of both tokens do not overflow in "_getRateUnderlyingAssetsToUsd".
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Both reserves are non zero and their product, the invariant k, does not overflow.
        vm.assume(testVars.reserve0 != 0);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;

        // And: The first mint yields at least the minimum liquidity the pool requires.
        vm.assume(FixedPointMathLib.sqrt(k) >= 2 * MINIMUM_LIQUIDITY);

        // And: The trusted reserve of token0 does not overflow.
        vm.assume(k / p0 < type(uint256).max / p1);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(FullMath.mulDiv(k, p1, p0));

        // And: The asset amount is above the largest one for which the amount of token0 fits in uint256.
        vm.assume(trustedReserve0 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve0 + 1, type(uint256).max);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        // Then: It reverts, the amount of token0 overflows.
        vm.expectRevert(bytes(""));
        metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Volatile_OverflowUnderlyingAssetAmount1(TestVariables memory testVars)
        public
    {
        // Given: The pool is volatile with two tokens of supported decimals.
        testVars.stable = false;
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And: The usd rates of both tokens do not overflow in "_getRateUnderlyingAssetsToUsd".
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Both reserves are non zero and their product, the invariant k, does not overflow.
        vm.assume(testVars.reserve0 != 0);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;

        // And: The first mint yields at least the minimum liquidity the pool requires.
        vm.assume(FixedPointMathLib.sqrt(k) >= 2 * MINIMUM_LIQUIDITY);

        // And: Both trusted reserves do not overflow.
        vm.assume(k / p0 < type(uint256).max / p1);
        uint256 trustedReserve1 = FullMath.mulDiv(FixedPointMathLib.sqrt(FullMath.mulDiv(k, p1, p0)), p0, p1);

        // And: The asset amount is above the largest one for which the amount of token1 fits in uint256.
        vm.assume(trustedReserve1 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve1 + 1, type(uint256).max);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        // Then: It reverts, the amount of token1 overflows.
        vm.expectRevert(bytes(""));
        metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_KOverflows(TestVariables memory testVars) public {
        // Given: A stable pool in a valid state, with the fuzzed reserve seeds kept aside.
        uint256 reserve0Seed = testVars.reserve0;
        uint256 reserve1Seed = testVars.reserve1;
        testVars = givenValidTestVarsStable(testVars);
        testVars = initAndSetValidStateInPoolFixture(testVars);

        // And: Both reserves are raised above the maximum supply supported for stable pools.
        reserve0Seed = bound(reserve0Seed, 15_511_800_965 * 10 ** testVars.decimals0, type(uint256).max);
        reserve1Seed = bound(reserve1Seed, 15_511_800_965 * 10 ** testVars.decimals1, type(uint256).max);
        stdstore.target(address(metadex03Pool)).sig(metadex03Pool.reserve0.selector).checked_write(reserve0Seed);
        stdstore.target(address(metadex03Pool)).sig(metadex03Pool.reserve1.selector).checked_write(reserve1Seed);

        // And: The pool is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        // Then: It reverts, the invariant k of the pool overflows.
        vm.expectRevert();
        metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_OverflowUnderlyingAssetAmount0(TestVariables memory testVars)
        public
    {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And: The pool is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: The asset amount is above the largest one for which the amount of token0 fits in uint256.
        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            metadex03PoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 0, underlyingAssetKeys);
        (uint256 trustedReserve0,) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);
        vm.assume(trustedReserve0 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve0 + 1, type(uint256).max);

        // When: The underlying asset amounts are queried.
        // Then: It reverts, the amount of token0 overflows.
        vm.expectRevert(bytes(""));
        metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_OverflowUnderlyingAssetAmount1(TestVariables memory testVars)
        public
    {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And: The pool is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: The asset amount is above the largest one for which the amount of token1 fits in uint256.
        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            metadex03PoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 0, underlyingAssetKeys);
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);
        vm.assume(trustedReserve1 > 1);

        // And: The amount of token0 does not overflow.
        uint256 maxAmount = trustedReserve0 > 0 ? type(uint256).max / trustedReserve0 : type(uint256).max;
        vm.assume(type(uint256).max / trustedReserve1 < maxAmount);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve1 + 1, maxAmount);

        // When: The underlying asset amounts are queried.
        // Then: It reverts, the amount of token1 overflows.
        vm.expectRevert(bytes(""));
        metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_ZeroRate0(TestVariables memory testVars) public {
        // Given: A volatile pool in a valid state.
        testVars = givenValidTestVarsVolatile(testVars);

        // And: The usd rate of token0 is zero.
        testVars.priceToken0 = 0;

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then: Both underlying amounts are zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_ZeroRate1(TestVariables memory testVars) public {
        // Given: A volatile pool in a valid state.
        testVars = givenValidTestVarsVolatile(testVars);

        // And: The usd rate of token1 is zero.
        testVars.priceToken1 = 0;

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then: Both underlying amounts are zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_NonZeroRate_NoPrecisionLoss(TestVariables memory testVars)
        public
    {
        // Given: A volatile pool in a valid state.
        testVars = givenValidTestVarsVolatile(testVars);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // When: The underlying asset amounts are queried.
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        // Then: Both amounts are the trusted reserves, pro rata the valued share of the supply.
        uint256 k = uint256(testVars.reserve0) * testVars.reserve1;
        (uint256 reserve0_, uint256 reserve1_,) = metadex03Pool.getReserves();
        assertEq(k, reserve0_ * reserve1_);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );
        assertEq(
            underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, metadex03Pool.totalSupply())
        );
        assertEq(
            underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, metadex03Pool.totalSupply())
        );

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: The amounts are in balance with the external prices, where rounding does not dominate.
        if (underlyingAssetsAmounts[0] > 1e4 && underlyingAssetsAmounts[1] > 1e4) {
            if (
                underlyingAssetsAmounts[0] > underlyingAssetsAmounts[1]
                    && 1e18 * testVars.priceToken1 / testVars.priceToken0 < type(uint256).max / 1e18
                    && underlyingAssetsAmounts[0]
                        < type(uint256).max / 10 ** (18 + testVars.decimals1 - testVars.decimals0)
            ) {
                assertApproxEqRel(
                    10 ** (18 + testVars.decimals1 - testVars.decimals0) * underlyingAssetsAmounts[0]
                        / underlyingAssetsAmounts[1],
                    1e18 * testVars.priceToken1 / testVars.priceToken0,
                    1e16
                );
            } else if (
                1e18 * testVars.priceToken0 / testVars.priceToken1 < type(uint256).max / 1e18
                    && underlyingAssetsAmounts[1]
                        < type(uint256).max / 10 ** (18 + testVars.decimals0 - testVars.decimals1)
            ) {
                assertApproxEqRel(
                    10 ** (18 + testVars.decimals0 - testVars.decimals1) * underlyingAssetsAmounts[1]
                        / underlyingAssetsAmounts[0],
                    1e18 * testVars.priceToken0 / testVars.priceToken1,
                    1e16
                );
            }
        }

        // And: The trusted reserves preserve the invariant k, where rounding does not dominate.
        uint256 kNew = trustedReserve0 * trustedReserve1;
        if (k > type(uint256).max / 1e18) {
            k = k / 1e18;
            kNew = kNew / 1e18;
        }
        if (trustedReserve0 > 5e3 && trustedReserve1 > 5e4) {
            assertApproxEqRel(kNew, k, 1e16);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_NonZeroRate_WithPrecisionLoss(TestVariables memory testVars)
        public
    {
        // Given: A volatile pool in a valid state.
        testVars = givenValidTestVarsVolatile(testVars);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // When: The underlying asset amounts are queried.
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        // Then: Both amounts are the trusted reserves, pro rata the valued share of the supply.
        uint256 k = uint256(testVars.reserve0) * testVars.reserve1;
        (uint256 reserve0_, uint256 reserve1_,) = metadex03Pool.getReserves();
        assertEq(k, reserve0_ * reserve1_);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );
        assertEq(
            underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, metadex03Pool.totalSupply())
        );
        assertEq(
            underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, metadex03Pool.totalSupply())
        );

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: Precision loss can only underestimate the invariant k.
        assertGe(k, trustedReserve0 * trustedReserve1);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_PricesTooFarApart(
        TestVariables memory testVars,
        bool token0Cheapest
    ) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The usd rates are so far apart that t rounds to zero.
        uint256 pLow = bound(testVars.priceToken0, 1, uint256(2 ** 127 - 1) / 1e18);
        uint256 pHigh = bound(testVars.priceToken1, pLow * 1e18, 2 ** 127 - 1);
        (testVars.priceToken0, testVars.priceToken1) = token0Cheapest ? (pLow, pHigh) : (pHigh, pLow);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And: The pool is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // When: The underlying asset amounts are queried.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: Nothing is valued, the trusted reserves are zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(trustedReserve0, 0);
        assertEq(trustedReserve1, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_LargeKExtremeRatio(TestVariables memory testVars)
        public
    {
        // Given: The pool is stable with two tokens of supported decimals.
        testVars.stable = true;
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And: Both reserves are below the maximum supply supported for stable pools, in the same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // forge-lint: disable-next-item(divide-before-multiply)
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // And: The first mint yields at least the minimum liquidity of the pool.
        vm.assume(FixedPointMathLib.sqrt(testVars.reserve0 * testVars.reserve1) >= 2 * MINIMUM_LIQUIDITY);
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // And: The usd rates are far enough apart that the intermediate x overflows, but t does not round to zero.
        vm.assume(k / (type(uint256).max / 1e18) >= 35);
        uint256 qMax = (k / (type(uint256).max / 1e18) - 1) / 2;
        testVars.priceToken0 = bound(testVars.priceToken0, 1, uint256(2 ** 127 - 1) * 16 / 1e18);
        testVars.priceToken1 =
            bound(testVars.priceToken1, testVars.priceToken0 * 1e18 / qMax + 1, testVars.priceToken0 * 1e18 / 16);

        // And: The valued amount is at most the supply of the pool.
        testVars.assetAmount =
            bound(testVars.assetAmount, 0, FixedPointMathLib.sqrt(testVars.reserve0 * testVars.reserve1));

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And: The pool is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // When: The underlying asset amounts are queried.
        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: The trusted reserves never overestimate the invariant k.
        uint256 kTrusted = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertLe(kTrusted, k);

        // And: Where rounding allows, the trusted reserves match the external prices and k.
        uint256 x = trustedReserve0 * 10 ** (18 - testVars.decimals0);
        uint256 y = trustedReserve1 * 10 ** (18 - testVars.decimals1);
        if (trustedReserve0 > 1e10 && trustedReserve1 > 1e10 && getRatio(x, y) >= 1e12) {
            assertApproxEqRel(getMarginalPrice(x, y), testVars.priceToken0 * 1e18 / testVars.priceToken1, 1e9);
            assertApproxEqRel(kTrusted / 1e18, k / 1e18, 1e10);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_RatioDownToOneWei(
        TestVariables memory testVars,
        bool token0Cheapest
    ) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The cheaper token is priced at one wei, the other at any supported price.
        uint256 pHigh = bound(testVars.priceToken1, 1, 2 ** 127 - 1);
        (testVars.priceToken0, testVars.priceToken1) = token0Cheapest ? (uint256(1), pHigh) : (pHigh, uint256(1));

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And: The pool is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // When: The underlying asset amounts are queried.
        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: The trusted reserves never overestimate the invariant k.
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        uint256 kTrusted = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertLe(kTrusted, k);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_ZeroRate0(TestVariables memory testVars) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The usd rate of token0 is zero.
        testVars.priceToken0 = 0;

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then: Both underlying amounts are zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_ZeroRate1(TestVariables memory testVars) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The usd rate of token1 is zero.
        testVars.priceToken1 = 0;

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: The underlying asset amounts are queried.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then: Both underlying amounts are zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_NonZeroRate(TestVariables memory testVars) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And: The pool is added to the AM.
            vm.prank(users.owner);
            metadex03PoolAM.addAsset(address(metadex03Pool));

            // When: The underlying asset amounts are queried.
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: Both amounts are the trusted reserves, pro rata the valued share of the supply.
        assertEq(
            underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, metadex03Pool.totalSupply())
        );
        assertEq(
            underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, metadex03Pool.totalSupply())
        );

        // And: The returned usd rates are those of the Registry.
        (uint256 token0Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AM.getValue(address(creditorUsd), testVars.token1, 0, 1e18);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: The trusted reserves never overestimate the invariant k.
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        uint256 kTrusted = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertLe(kTrusted, k);

        // And: The trusted reserves are in equilibrium with the external prices and preserve k, where rounding does not dominate.
        uint256 x = trustedReserve0 * 10 ** (18 - testVars.decimals0);
        uint256 y = trustedReserve1 * 10 ** (18 - testVars.decimals1);
        if (trustedReserve0 > 1e10 && trustedReserve1 > 1e10 && getRatio(x, y) >= 1e12) {
            assertApproxEqRel(getMarginalPrice(x, y), testVars.priceToken0 * 1e18 / testVars.priceToken1, 1e9);
            assertApproxEqRel(kTrusted / 1e18, k / 1e18, 1e10);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_Equilibrium(TestVariables memory testVars) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The pool is realistic, rounding the trusted reserves to token units is negligible.
        vm.assume(testVars.decimals0 >= 6 && testVars.decimals1 >= 6);
        vm.assume(testVars.reserve0 >= 1e6 * 10 ** testVars.decimals0);
        testVars.priceToken0 = bound(testVars.priceToken0, 1e15, 1e21);
        testVars.priceToken1 = bound(testVars.priceToken1, testVars.priceToken0 / 1e3, testVars.priceToken0 * 1e3);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And: The pool is added to the AM.
            vm.prank(users.owner);
            metadex03PoolAM.addAsset(address(metadex03Pool));

            (, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        // When: The trusted reserves are calculated.
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: The marginal price of the trusted reserves equals the ratio of the external prices.
        uint256 x = trustedReserve0 * 10 ** (18 - testVars.decimals0);
        uint256 y = trustedReserve1 * 10 ** (18 - testVars.decimals1);
        assertApproxEqRel(getMarginalPrice(x, y), testVars.priceToken0 * 1e18 / testVars.priceToken1, 1e10);

        // And: The trusted reserves preserve the invariant k, but never overestimate it.
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        uint256 kTrusted = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertLe(kTrusted, k);
        assertApproxEqRel(kTrusted / 1e18, k / 1e18, 1e10);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_Parity(TestVariables memory testVars) public {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: Both tokens have the same usd rate.
        testVars.priceToken1 = testVars.priceToken0;

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And: The pool is added to the AM.
            vm.prank(users.owner);
            metadex03PoolAM.addAsset(address(metadex03Pool));

            (, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        // When: The trusted reserves are calculated.
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: The trusted reserves are balanced.
        uint256 unitCorrection0 = 10 ** (18 - testVars.decimals0);
        uint256 unitCorrection1 = 10 ** (18 - testVars.decimals1);
        assertApproxEqAbs(
            trustedReserve0 * unitCorrection0,
            trustedReserve1 * unitCorrection1,
            unitCorrection0 > unitCorrection1 ? unitCorrection0 : unitCorrection1
        );

        // And: The trusted reserves never overestimate the invariant k.
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        uint256 kTrusted = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertLe(kTrusted, k);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_NearParityLargePrices(TestVariables memory testVars)
        public
    {
        // Given: A stable pool in a valid state.
        testVars = givenValidTestVarsStable(testVars);

        // And: The usd rates are large and one apart, so their ratio exceeds type(uint256).max / 1e36.
        testVars.priceToken0 = bound(testVars.priceToken0, 1e24, 2 ** 127 - 2);
        testVars.priceToken1 = testVars.priceToken0 + 1;

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And: The pool is added to the AM.
            vm.prank(users.owner);
            metadex03PoolAM.addAsset(address(metadex03Pool));

            (, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        // When: The trusted reserves are calculated.
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);

        // Then: The trusted reserves never overestimate the invariant k.
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        uint256 kTrusted = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertLe(kTrusted, k);

        // And: The trusted reserves are in equilibrium with the external prices and preserve k, where rounding does not dominate.
        uint256 x = trustedReserve0 * 10 ** (18 - testVars.decimals0);
        uint256 y = trustedReserve1 * 10 ** (18 - testVars.decimals1);
        if (trustedReserve0 > 1e10 && trustedReserve1 > 1e10) {
            assertApproxEqRel(getMarginalPrice(x, y), testVars.priceToken0 * 1e18 / testVars.priceToken1, 1e9);
            assertApproxEqRel(kTrusted / 1e18, k / 1e18, 1e10);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_TestFormulas(uint256 assetAmount) public {
        // Given: A volatile pool of two tokens worth 1 usd each, with reserves in balance with those prices.
        uint256 initReserve0 = 1_111_111 * 1e18;
        uint256 initReserve1 = 1_111_111 * 1e6;
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        {
            ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", 18);
            ERC20Mock token1;
            while (address(token1) < address(token0)) {
                token1 = new ERC20Mock("Token 1", "TOK1", 6);
            }
            metadex03Pool = createPoolMetadex03(address(token0), address(token1), false);
            addAssetToArcadia(address(token0), int256(1e18));
            addAssetToArcadia(address(token1), int256(1e18));
            deal(address(token0), address(metadex03Pool), initReserve0);
            deal(address(token1), address(metadex03Pool), initReserve1);
            metadex03Pool.mint(users.accountOwner);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));

            // And: A swap moves the reserves along the curve, away from the external prices.
            uint256 amount0In = 990_999 * 1e18;
            uint256 amount1Out = metadex03Pool.getAmountOut(amount0In, address(token0));
            deal(address(token0), users.accountOwner, amount0In);
            vm.prank(users.accountOwner);
            // forge-lint: disable-next-line(erc20-unchecked-transfer)
            token0.transfer(address(metadex03Pool), amount0In);
            metadex03Pool.swap(0, amount1Out, users.accountOwner, "");
        }

        // And: The valued amount is at most the total supply of the pool.
        assetAmount = bound(assetAmount, 0, metadex03Pool.totalSupply());
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));

        // When: The underlying asset amounts are queried.
        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            metadex03PoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, assetAmount, underlyingAssetKeys);

        // Then: The documented formulas recover the reserves the pool held before the swap.
        uint256 trustedReserve0;
        {
            (uint256 reserve0_, uint256 reserve1_,) = metadex03Pool.getReserves();
            trustedReserve0 = FixedPointMathLib.sqrt(
                FullMath.mulDiv(
                    rateUnderlyingAssetsToUsd[1].assetValue,
                    reserve0_ * reserve1_,
                    rateUnderlyingAssetsToUsd[0].assetValue
                )
            );
        }
        assertApproxEqAbs(trustedReserve0, initReserve0, 1e12);
        assertEq(
            FullMath.mulDiv(
                trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
            ),
            initReserve1
        );
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_ReserveShiftKeepsValue(
        TestVariables memory testVars,
        uint256 shift
    ) public {
        // Given: A volatile pool in a valid state.
        testVars = givenValidTestVarsVolatile(testVars);

        // And: The reserves can be shifted along the curve without truncating the invariant k.
        shift = bound(shift, 2, 16);
        vm.assume(testVars.reserve1 % shift == 0);
        vm.assume(testVars.reserve0 <= type(uint256).max / shift);

        // And: The state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        // forge-lint: disable-next-item(unsafe-typecast)
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And: The underlying amounts before the shift are read.
        (uint256[] memory amountsBefore,) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // And: The reserves are shifted along the constant product curve, as a swap would do.
        deal(testVars.token0, address(metadex03Pool), testVars.reserve0 * shift);
        deal(testVars.token1, address(metadex03Pool), testVars.reserve1 / shift);
        metadex03Pool.sync();
        (uint256 reserve0_, uint256 reserve1_,) = metadex03Pool.getReserves();
        assertEq(reserve0_ * reserve1_, uint256(testVars.reserve0) * testVars.reserve1);

        // When: The underlying asset amounts are queried again.
        (uint256[] memory amountsAfter,) = metadex03PoolAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then: The valuation is unchanged, it depends on the invariant and not on how the reserves are split.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_TestFormulas(uint256 assetAmount) public {
        // Given: A stable pool of two tokens worth 1 usd each, with reserves in balance with those prices.
        uint8 decimals0 = 18;
        uint8 decimals1 = 4;
        uint256 initReserve0 = 1111 * 10 ** decimals0;
        uint256 initReserve1 = 1111 * 10 ** decimals1;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", decimals0);
            ERC20Mock token1;
            while (address(token1) < address(token0)) {
                token1 = new ERC20Mock("Token 1", "TOK1", decimals1);
            }
            metadex03Pool = createPoolMetadex03(address(token0), address(token1), true);
            addAssetToArcadia(address(token0), int256(1e18));
            addAssetToArcadia(address(token1), int256(1e18));
            deal(address(token0), address(metadex03Pool), initReserve0);
            deal(address(token1), address(metadex03Pool), initReserve1);
            metadex03Pool.mint(users.accountOwner);

            // And: The pool is added to the AM.
            vm.prank(users.owner);
            metadex03PoolAM.addAsset(address(metadex03Pool));

            // And: A swap moves the reserves along the curve, away from the external prices.
            uint256 amount0In = 10_000 * 10 ** decimals0;
            uint256 amount1Out = metadex03Pool.getAmountOut(amount0In, address(token0));
            deal(address(token0), users.accountOwner, amount0In);
            vm.startPrank(users.accountOwner);
            // forge-lint: disable-next-line(erc20-unchecked-transfer)
            token0.transfer(address(metadex03Pool), amount0In);
            metadex03Pool.swap(0, amount1Out, users.accountOwner, "");
            vm.stopPrank();

            // And: The valued amount is at most the total supply of the pool.
            assetAmount = bound(assetAmount, 0, metadex03Pool.totalSupply());
            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
            // forge-lint: disable-next-item(unsafe-typecast)
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));
            // forge-lint: disable-next-item(unsafe-typecast)
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));

            // When: The underlying asset amounts are queried.
            (, rateUnderlyingAssetsToUsd) = metadex03PoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, assetAmount, underlyingAssetKeys
            );
        }

        // Then: The trusted reserves recover the reserves the pool held before the swap.
        (uint256 trustedReserve0, uint256 trustedReserve1) =
            metadex03PoolAM.getTrustedReservesStable(address(metadex03Pool), rateUnderlyingAssetsToUsd);
        assertApproxEqAbs(trustedReserve0, initReserve0, (10 ** decimals0) - 2);
        assertApproxEqAbs(trustedReserve1, initReserve1, (10 ** decimals1) - 2);
    }
}
