/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromePoolAM_Fuzz_Test, FixedPointMathLib, FullMath, ERC20Mock } from "./_AerodromePoolAM.fuzz.t.sol";

import { stdError } from "../../../../lib/forge-std/src/StdError.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "AerodromePoolAM".
 */
contract GetUnderlyingAssetsAmounts_AerodromePoolAM_Fuzz_Test is AerodromePoolAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromePoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Volatile_OverflowReserve0(TestVariables memory testVars)
        public
    {
        // Given : pool is volatile.
        testVars.stable = false;

        // And : decimals should be max equal to 18
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : "rateUnderlyingAssetsToUsd" for token0 and token1 does not overflows in "_getRateUnderlyingAssetsToUsd"
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Reserves should not be zero.
        // And: liquidity should be greater than minimum liquidity.
        // And: k should not overflow.
        testVars.reserve0 = bound(testVars.reserve0, 1, type(uint256).max);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;
        uint256 totalSupply = FixedPointMathLib.sqrt(k);

        // And: liquidity should be strictly greater than minimum liquidity.
        vm.assume(totalSupply > MINIMUM_LIQUIDITY);

        // And: trustedReserve0 overflows (test-case).
        // Only happens with absurdly big reserve1 and p1 -> USD value exceeding type(uint256).max.
        vm.assume(k / p0 > type(uint256).max / p1);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Volatile_OverflowUnderlyingAssetAmount0(
        TestVariables memory testVars
    ) public {
        // Given : pool is volatile.
        testVars.stable = false;

        // And : decimals should be max equal to 18
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : "rateUnderlyingAssetsToUsd" for token0 and token1 does not overflows in "_getRateUnderlyingAssetsToUsd"
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Reserves should not be zero.
        // And: liquidity should be greater than minimum liquidity.
        // And: k should not overflow.
        testVars.reserve0 = bound(testVars.reserve0, 1, type(uint256).max);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;
        uint256 totalSupply = FixedPointMathLib.sqrt(k);

        // And: liquidity should be strictly greater than minimum liquidity.
        vm.assume(totalSupply > MINIMUM_LIQUIDITY);

        // And: trustedReserve0 does not overflow
        vm.assume(k / p0 < type(uint256).max / p1);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(FullMath.mulDiv(k, p1, p0));

        // And: underlyingAssetsAmounts overflows (test-case).
        vm.assume(trustedReserve0 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve0 + 1, type(uint256).max);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Volatile_OverflowUnderlyingAssetAmount1(
        TestVariables memory testVars
    ) public {
        // Given : pool is volatile.
        testVars.stable = false;

        // And : decimals should be max equal to 18
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : "rateUnderlyingAssetsToUsd" for token0 and token1 does not overflows in "_getRateUnderlyingAssetsToUsd"
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Reserves should not be zero.
        // And: liquidity should be greater than minimum liquidity.
        // And: k should not overflow.
        testVars.reserve0 = bound(testVars.reserve0, 1, type(uint256).max);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;
        uint256 totalSupply = FixedPointMathLib.sqrt(k);

        // And: liquidity should be strictly greater than minimum liquidity.
        vm.assume(totalSupply > MINIMUM_LIQUIDITY);

        // And: trustedReserve0 does not overflow
        vm.assume(k / p0 < type(uint256).max / p1);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(FullMath.mulDiv(k, p1, p0));
        uint256 trustedReserve1 = FullMath.mulDiv(trustedReserve0, p0, p1);

        // And: underlyingAssetsAmounts overflows (test-case).
        vm.assume(trustedReserve1 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve1 + 1, type(uint256).max);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When: Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_KOverflows(TestVariables memory testVars) public {
        // Cache initial seed for the reserves.
        uint256 reserve0_ = testVars.reserve0;
        uint256 reserve1_ = testVars.reserve1;

        // Given : Valid state
        testVars = givenValidTestVarsStable(testVars);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        // And reserves are increased to that k reverts.
        reserve0_ = bound(reserve0_, 15_511_800_965 * 10 ** testVars.decimals0, type(uint256).max);
        reserve1_ = bound(reserve1_, 15_511_800_965 * 10 ** testVars.decimals1, type(uint256).max);
        stdstore.target(address(pool)).sig(pool.reserve0.selector).checked_write(reserve0_);
        stdstore.target(address(pool)).sig(pool.reserve1.selector).checked_write(reserve1_);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And : Pool is added to the AM
        aeroFactoryMock.setPool(address(pool));
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(pool));

        // When : Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert();
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_COverflows(TestVariables memory testVars) public {
        // Given : pool is stable.
        testVars.stable = true;

        // And : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // Root (reserve0 * reserve1) should be greater than minimum liquidty
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: c overflows (test-case).
        // And: prices are positive.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, k - 1);
        testVars.priceToken0 = bound(testVars.priceToken0, 1, uint256(type(int256).max));
        vm.assume(FullMath.mulDiv(type(uint256).max, testVars.priceToken0, k) + 1 <= uint256(type(int256).max));
        testVars.priceToken1 = bound(
            testVars.priceToken1,
            FullMath.mulDiv(type(uint256).max, testVars.priceToken0, k) + 1,
            uint256(type(int256).max)
        );
        vm.assume(k / testVars.priceToken0 > type(uint256).max / testVars.priceToken1);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And : Pool is added to the AM
        aeroFactoryMock.setPool(address(pool));
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(pool));

        // When : Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_DOverflows(TestVariables memory testVars) public {
        // Given : pool is stable.
        testVars.stable = true;

        // And : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // Root (reserve0 * reserve1) should be greater than minimum liquidity
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: d overflows (test-case)
        // And: prices are positive.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        if (testVars.priceToken0 <= type(uint128).max) {
            testVars.priceToken1 = bound(
                testVars.priceToken1,
                FixedPointMathLib.sqrt(type(uint256).max - testVars.priceToken0 ** 2) + 1,
                type(uint256).max / 1e18
            );
        }

        // And: c does not overflow
        vm.assume(k / testVars.priceToken0 <= type(uint256).max / testVars.priceToken1);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And : Pool is added to the AM
        aeroFactoryMock.setPool(address(pool));
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(pool));

        // When : Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(stdError.arithmeticError);
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_XOverflows(TestVariables memory testVars) public {
        // Given : pool is stable.
        testVars.stable = true;

        // And : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // Root (reserve0 * reserve1) should be greater than minimum liquidty
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: d does not overflow.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, 2 ** 127 - 1);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, 2 ** 127 - 1);
        uint256 p0 = testVars.priceToken0;
        uint256 p1 = testVars.priceToken1;
        uint256 d = p0 * p0 + p1 * p1;

        // And: c does not overflow
        vm.assume(k / p0 <= type(uint256).max / p1);
        uint256 c = FullMath.mulDiv(k, p1, p0);

        // And: x overflows (test-case).
        vm.assume(c / d > type(uint256).max / 1e36);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And : Pool is added to the AM
        aeroFactoryMock.setPool(address(pool));
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(pool));

        // When : Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_OverflowUnderlyingAssetAmount0(
        TestVariables memory testVars
    ) public {
        // Given : pool is stable.
        testVars.stable = true;

        // And : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // Root (reserve0 * reserve1) should be greater than minimum liquidty
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: d does not overflow.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, 2 ** 127 - 1);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, 2 ** 127 - 1);
        uint256 p0 = testVars.priceToken0;
        uint256 p1 = testVars.priceToken1;
        uint256 d = p0 * p0 + p1 * p1;

        // And: c does not overflow
        vm.assume(k / p0 <= type(uint256).max / p1);
        uint256 c = FullMath.mulDiv(k, p1, p0);

        // And: x does not overflow.
        vm.assume(c / d <= type(uint256).max / 1e36);

        uint256 trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
        trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);
        // And: underlyingAssetsAmount0 overflows (test-case).
        vm.assume(trustedReserve0 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve0 + 1, type(uint256).max);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And : Pool is added to the AM
        aeroFactoryMock.setPool(address(pool));
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(pool));

        // When : Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Stable_OverflowUnderlyingAssetAmount1(
        TestVariables memory testVars
    ) public {
        // Given : pool is stable.
        testVars.stable = true;

        // And : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // Root (reserve0 * reserve1) should be greater than minimum liquidty
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: d does not overflow.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, 2 ** 127 - 1);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, 2 ** 127 - 1);
        uint256 p0 = testVars.priceToken0;
        uint256 p1 = testVars.priceToken1;
        uint256 d = p0 * p0 + p1 * p1;

        // And: c does not overflow
        vm.assume(k / p0 <= type(uint256).max / p1);
        uint256 c = FullMath.mulDiv(k, p1, p0);

        // And: x does not overflow.
        vm.assume(c / d <= type(uint256).max / 1e36);

        uint256 trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
        trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0,
            10 ** (18 - testVars.decimals0) * testVars.priceToken0,
            10 ** (18 - testVars.decimals1) * testVars.priceToken1
        );
        // And: underlyingAssetsAmounts overflows (test-case).
        vm.assume(trustedReserve1 > 1);
        testVars.assetAmount = bound(testVars.assetAmount, type(uint256).max / trustedReserve1 + 1, type(uint256).max);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // And : Pool is added to the AM
        aeroFactoryMock.setPool(address(pool));
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(pool));

        // When : Calling getUnderlyingAssetsAmounts()
        // Then: It should revert
        vm.expectRevert(bytes(""));
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_ZeroRate0(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVarsVolatile(testVars);

        // And : rate of asset0 is zero.
        testVars.priceToken0 = 0;

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts()
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_ZeroRate1(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVarsVolatile(testVars);

        // And : rate of asset0 is zero.
        testVars.priceToken1 = 0;

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts()
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_NonZeroRate_NoPrecisionLoss(
        TestVariables memory testVars
    ) public {
        // Given : Valid state
        testVars = givenValidTestVarsVolatile(testVars);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // When : Calling getUnderlyingAssetsAmounts()
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = aeroPoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        uint256 k = uint256(testVars.reserve0) * testVars.reserve1;
        (uint256 reserve0_, uint256 reserve1_,) = pool.getReserves();
        assertEq(k, reserve0_ * reserve1_);

        uint256 trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );

        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, pool.totalSupply()));
        assertEq(underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, pool.totalSupply()));

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: The amounts should be in balance with the external prices.
        // For very low amounts, a rounding error already invalidates the assertions.
        // "assertApproxEqRel()" should not overflow.
        if (underlyingAssetsAmounts[0] > 1e2 && underlyingAssetsAmounts[1] > 1e2) {
            if (
                underlyingAssetsAmounts[0] > underlyingAssetsAmounts[1]
                    && 1e18 * testVars.priceToken1 / testVars.priceToken0 < type(uint256).max / 1e18
            ) {
                assertApproxEqRel(
                    10 ** (18 + testVars.decimals1 - testVars.decimals0) * underlyingAssetsAmounts[0]
                        / underlyingAssetsAmounts[1],
                    1e18 * testVars.priceToken1 / testVars.priceToken0,
                    1e16
                );
            } else if (1e18 * testVars.priceToken0 / testVars.priceToken1 < type(uint256).max / 1e18) {
                assertApproxEqRel(
                    10 ** (18 + testVars.decimals0 - testVars.decimals1) * underlyingAssetsAmounts[1]
                        / underlyingAssetsAmounts[0],
                    1e18 * testVars.priceToken0 / testVars.priceToken1,
                    1e16
                );
            }
        }

        // And: k-value of the pool with trustedReserves remains the same.
        // For very low reserves, a rounding error already invalidates the assertions.
        // "assertApproxEqRel()" should not overflow.
        uint256 kNew = trustedReserve0 * trustedReserve1;
        if (k > type(uint256).max / 1e18) {
            // "assertApproxEqRel()" should not overflow.
            k = k / 1e18;
            kNew = kNew / 1e18;
        }
        if (trustedReserve0 > 5e3 && trustedReserve1 > 5e4) {
            assertApproxEqRel(kNew, k, 1e16);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_NonZeroRate_WithPrecisionLoss(
        TestVariables memory testVars
    ) public {
        // Given : Valid state
        testVars = givenValidTestVarsVolatile(testVars);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // When : Calling getUnderlyingAssetsAmounts()
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = aeroPoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );
        }

        uint256 k = uint256(testVars.reserve0) * testVars.reserve1;
        (uint256 reserve0_, uint256 reserve1_,) = pool.getReserves();
        assertEq(k, reserve0_ * reserve1_);

        uint256 trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );

        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, pool.totalSupply()));
        assertEq(underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, pool.totalSupply()));

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: k-value of the pool with trustedReserves should be strictly smaller.
        // All errors due to precision loss should always underestimate k.
        uint256 kNew = trustedReserve0 * trustedReserve1;
        assertGe(k, kNew);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_ZeroRate0(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVarsStable(testVars);

        // And : rate of asset0 is zero.
        testVars.priceToken0 = 0;

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts()
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_ZeroRate1(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVarsStable(testVars);

        // And : rate of asset0 is zero.
        testVars.priceToken1 = 0;

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts()
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys);

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_NonZeroRate_NoPrecisionLoss(
        TestVariables memory testVars
    ) public {
        // Given : Valid state
        testVars = givenValidTestVarsStable(testVars);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256 trustedReserve0;
        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        uint256 k;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And : Pool is added to the AM
            aeroFactoryMock.setPool(address(pool));
            vm.prank(users.creatorAddress);
            aeroPoolAM.addAsset(address(pool));

            // When : Calling getUnderlyingAssetsAmounts()
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = aeroPoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );

            k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

            uint256 p0 = testVars.priceToken0;
            uint256 p1 = testVars.priceToken1;

            uint256 c = FullMath.mulDiv(k, p1, p0); // 18 decimals
            uint256 d = p0 * p0 + p1 * p1; // 18 decimals

            // And: Division/sqrt before multiplication does not lead to precision loss
            // (should not be possible with realistic usd-rates).
            vm.assume(FullMath.mulDiv(1e36, c, d) > 1e5);

            trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
            trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);
        }
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, pool.totalSupply()));
        assertEq(underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, pool.totalSupply()));

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: The amounts should be in balance with the external prices.
        // For very low amounts, a rounding error already invalidates the assertions.
        // "assertApproxEqRel()" should not overflow.
        if (underlyingAssetsAmounts[0] > 1e2 && underlyingAssetsAmounts[1] > 1e2) {
            if (
                underlyingAssetsAmounts[0] > underlyingAssetsAmounts[1]
                    && 1e18 * testVars.priceToken1 / testVars.priceToken0 < type(uint256).max / 1e18
            ) {
                assertApproxEqRel(
                    10 ** (18 + testVars.decimals1 - testVars.decimals0) * underlyingAssetsAmounts[0]
                        / underlyingAssetsAmounts[1],
                    1e18 * testVars.priceToken1 / testVars.priceToken0,
                    1e16
                );
            } else if (1e18 * testVars.priceToken0 / testVars.priceToken1 < type(uint256).max / 1e18) {
                assertApproxEqRel(
                    10 ** (18 + testVars.decimals0 - testVars.decimals1) * underlyingAssetsAmounts[1]
                        / underlyingAssetsAmounts[0],
                    1e18 * testVars.priceToken0 / testVars.priceToken1,
                    1e16
                );
            }
        }

        // And: k-value of the pool with trustedReserves remains the same.
        // For very low reserves, a rounding error already invalidates the assertions.
        uint256 kNew = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        if (k > type(uint256).max / 1e18) {
            // "assertApproxEqRel()" should not overflow.
            k = k / 1e18;
            kNew = kNew / 1e18;
        }
        if (trustedReserve0 > 5e3 && trustedReserve1 > 5e3) {
            assertApproxEqRel(kNew, k, 1e16);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_NonZeroRate_WithPrecisionLoss(
        TestVariables memory testVars
    ) public {
        // Given : Valid state
        testVars = givenValidTestVarsStable(testVars);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256 trustedReserve0;
        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        uint256 k;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And : Pool is added to the AM
            aeroFactoryMock.setPool(address(pool));
            vm.prank(users.creatorAddress);
            aeroPoolAM.addAsset(address(pool));

            // When : Calling getUnderlyingAssetsAmounts()
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = aeroPoolAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );

            k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

            uint256 p0 = testVars.priceToken0;
            uint256 p1 = testVars.priceToken1;

            uint256 c = FullMath.mulDiv(k, p1, p0); // 18 decimals
            uint256 d = p0 * p0 + p1 * p1; // 18 decimals

            trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
            trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);
        }
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, pool.totalSupply()));
        assertEq(underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, pool.totalSupply()));

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        // And: k-value of the pool with trustedReserves should be strictly smaller.
        // All errors due to precision loss should always underestimate k.
        uint256 kNew = getK(trustedReserve0, trustedReserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        assertGe(k, kNew);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Volatile_TestFormulas() public {
        uint256 initReserve0 = 1_111_111 * 1e18;
        uint256 initReserve1 = 1_111_111 * 1e6;

        // Given : Deploy two tokens for the new Aerodrome tokenPair
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", 18);
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", 6);

        deployAerodromeFixture(address(token0), address(token1), false);

        // And : The tokens of the pool are added to the Arcadia protocol with price 1e18
        addUnderlyingTokenToArcadia(address(token0), int256(1e18));
        addUnderlyingTokenToArcadia(address(token1), int256(1e18));

        deal(address(token0), address(pool), initReserve0);
        deal(address(token1), address(pool), initReserve1);

        // And : A first position is minted
        pool.mint(users.accountOwner);

        uint256 amount0In = 990_999 * 1e18;
        uint256 amount1Out = pool.getAmountOut(amount0In, address(token0));

        // And : We swap tokens (but do not change relative price)
        deal(address(token0), users.accountOwner, amount0In);
        vm.prank(users.accountOwner);
        token0.transfer(address(pool), amount0In);

        pool.swap(0, amount1Out, users.accountOwner, "");

        (uint256 reserve0_, uint256 reserve1_,) = pool.getReserves();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));

        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 100, underlyingAssetKeys);

        uint256 k = reserve0_ * reserve1_;

        // r0' = sqrt((p1 * k) / p0)
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );

        // r1' = (r0' * p0) / p1
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        // Max diff is less than 1, due to rounding diffs, minor
        // Diff does not increase with increase of amount swapped
        assertApproxEqAbs(trustedReserve0, initReserve0, 1e12);
        assertEq(trustedReserve1, initReserve1);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Stable_TestFormulas_Stable() public {
        uint8 decimals0 = 18;
        uint8 decimals1 = 4;
        uint256 initReserve0 = 1111 * 10 ** decimals0;
        uint256 initReserve1 = 1111 * 10 ** decimals1;

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        uint256 reserve0_;
        uint256 reserve1_;
        {
            // Given : Deploy two tokens for the new Aerodrome tokenPair
            ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", decimals0);
            ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", decimals1);
            deployAerodromeFixture(address(token0), address(token1), true);

            // And : The tokens of the pool are added to the Arcadia protocol with price of 1
            addUnderlyingTokenToArcadia(address(token0), int256(1e18));
            addUnderlyingTokenToArcadia(address(token1), int256(1e18));

            deal(address(token0), address(pool), initReserve0);
            deal(address(token1), address(pool), initReserve1);

            // And : A first position is minted
            pool.mint(users.accountOwner);

            // And : Add the pool to the AM
            aeroFactoryMock.setPool(address(pool));
            vm.prank(users.creatorAddress);
            aeroPoolAM.addAsset(address(pool));

            (reserve0_, reserve1_,) = pool.getReserves();

            uint256 amount0In = 10_000 * 10 ** decimals0;
            uint256 amount1Out = pool.getAmountOut(amount0In, address(token0));

            // And : We swap tokens (but do not change relative price)
            deal(address(token0), users.accountOwner, amount0In);
            vm.startPrank(users.accountOwner);
            token0.transfer(address(pool), amount0In);

            pool.swap(0, amount1Out, users.accountOwner, "");
            vm.stopPrank();

            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));

            (, rateUnderlyingAssetsToUsd) =
                aeroPoolAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 100, underlyingAssetKeys);
        }

        (reserve0_, reserve1_,) = pool.getReserves();

        // x = ∜[k(r0, r1) * p1³ / (p0 * p1² + p0³)].
        uint256 trustedReserve0;
        {
            uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue / 10 ** (18 - decimals0);
            uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue / 10 ** (18 - decimals1);

            uint256 k = getK(reserve0_, reserve1_, 10 ** decimals0, 10 ** decimals1);

            uint256 c = FullMath.mulDiv(k, p1, p0);
            uint256 d = p0 * p0 + p1 * p1;

            trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
        }
        trustedReserve0 = trustedReserve0 / (1e18 / 10 ** decimals0);
        // r1' = r0' * P0usd / P1usd.
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        assertApproxEqAbs(trustedReserve0, initReserve0, (10 ** decimals0) - 2);
        assertApproxEqAbs(trustedReserve1, initReserve1, (10 ** decimals1) - 2);
    }
}
