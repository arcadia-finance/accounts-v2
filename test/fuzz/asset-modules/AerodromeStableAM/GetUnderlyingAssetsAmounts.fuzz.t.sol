/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeStableAM_Fuzz_Test } from "./_AerodromeStableAM.fuzz.t.sol";

import { FixedPointMathLib, FullMath, ERC20Mock } from "../AerodromeVolatileAM/_AerodromeVolatileAM.fuzz.t.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { AerodromeVolatileAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "AerodromeStableAM".
 */
contract GetUnderlyingAssetsAmounts_AerodromeStableAM_Fuzz_Test is AerodromeStableAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    uint256 success;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeStableAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssetsAmounts_ZeroRate0(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVars(testVars);

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
        aeroStableAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_ZeroRate1(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVars(testVars);

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
        aeroStableAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_NonZeroRate_Stable(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = givenValidTestVars(testVars);

        // And state is persisted.
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256 trustedReserve0;
        uint256 trustedReserve1_;
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
            aeroStableAM.addAsset(address(pool));

            // When : Calling getUnderlyingAssetsAmounts()
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = aeroStableAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );

            k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

            uint256 p0 = testVars.priceToken0;
            uint256 p1 = testVars.priceToken1;
            //uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue;
            //uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue;

            uint256 c = FullMath.mulDiv(k, p1, p0); // 18 decimals
            uint256 d = p0 * p0 + p1 * p1; // 18 decimals

            trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
            trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);

            vm.assume(k / p1 <= type(uint256).max / p0);
            c = FullMath.mulDiv(k, p0, p1); // 18 decimals
            vm.assume(c / d <= type(uint256).max / 1e36);
            trustedReserve1_ = FixedPointMathLib.sqrt(p0 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
            trustedReserve1_ = trustedReserve1_ / 10 ** (18 - testVars.decimals1);
            vm.assume(trustedReserve1_ > 0);
        }
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );
        emit log_named_uint("testVars.reserve0", testVars.reserve0);
        emit log_named_uint("testVars.reserve1", testVars.reserve1);
        emit log_named_uint("trustedReserve0", trustedReserve0);
        emit log_named_uint("trustedReserve1", trustedReserve1);
        emit log_named_uint("trustedReserve1_", trustedReserve1_);

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts[0], trustedReserve0.mulDivDown(testVars.assetAmount, pool.totalSupply()));
        assertEq(underlyingAssetsAmounts[1], trustedReserve1.mulDivDown(testVars.assetAmount, pool.totalSupply()));

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, token0Value);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, token1Value);

        vm.assume(underlyingAssetsAmounts[0] > 1e2 && underlyingAssetsAmounts[1] > 1e2);

        // And: The amounts should be in balance with the external prices.
        // For very low amounts, a rounding error already invalidates the assertions.
        // "assertApproxEqRel()" should not overflow.
        emit log_named_uint("underlyingAssetsAmounts[0]", underlyingAssetsAmounts[0]);
        emit log_named_uint("underlyingAssetsAmounts[1]", underlyingAssetsAmounts[1]);
        emit log_named_uint("testVars.priceToken0", testVars.priceToken0);
        emit log_named_uint("testVars.priceToken1", testVars.priceToken1);
        emit log_named_uint("testVars.decimals0", testVars.decimals0);
        emit log_named_uint("testVars.decimals1", testVars.decimals1);
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
        emit log_named_uint("k", k);
        if (trustedReserve0 > 1e3 && trustedReserve1 > 1e3 && k < type(uint256).max / 1e18) {
            emit log_named_uint("kNew", kNew);
            assertApproxEqRel(kNew, k, 1e16);

            emit log_named_uint("success", success++);
        }
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_TestFormulas_Stable() public {
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
            deployAerodromeStableFixture(address(token0), address(token1));

            // And : The tokens of the pool are added to the Arcadia protocol with price of 1
            addUnderlyingTokenToArcadia(address(token0), int256(1e18));
            addUnderlyingTokenToArcadia(address(token1), int256(1e18));

            deal(address(token0), address(pool), initReserve0);
            deal(address(token1), address(pool), initReserve1);

            // And : A first position is minted
            pool.mint(users.accountOwner);

            // And : Add the pool to the AM
            aeroFactoryMock.setPool(address(pool));
            aeroStableAM.addAsset(address(pool));

            (reserve0_, reserve1_,) = pool.getReserves();

            uint256 amount0In = 10_000 * 10 ** decimals0;
            uint256 amount1Out = pool.getAmountOut(amount0In, address(token0));
            emit log_named_uint("amount1 out", amount1Out);

            // And : We swap tokens (but do not change relative price)
            deal(address(token0), users.accountOwner, amount0In);
            vm.startPrank(users.accountOwner);
            token0.transfer(address(pool), amount0In);

            pool.swap(0, amount1Out, users.accountOwner, "");
            vm.stopPrank();

            emit log_named_uint("asset0 fees", token0.balanceOf(pool.poolFees()));
            emit log_named_uint("asset1 fees", token1.balanceOf(pool.poolFees()));
            emit log_named_uint("pool asset0 balance", token0.balanceOf(address(pool)));
            emit log_named_uint("pool asset1 balance", token1.balanceOf(address(pool)));
            emit log_named_uint("user asset1 balance received", token1.balanceOf(users.accountOwner));

            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));

            (, rateUnderlyingAssetsToUsd) =
                aeroStableAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 100, underlyingAssetKeys);
        }
        emit log_named_uint("k_init", getK(reserve0_, reserve1_, 10 ** decimals0, 10 ** decimals1));

        (reserve0_, reserve1_,) = pool.getReserves();
        emit log_named_uint("untrusted 0", reserve0_);
        emit log_named_uint("untrusted 1", reserve1_);

        uint256 trustedReserve0;
        {
            uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue / 10 ** (18 - decimals0);
            uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue / 10 ** (18 - decimals1);

            uint256 k = getK(reserve0_, reserve1_, 10 ** decimals0, 10 ** decimals1);
            emit log_named_uint("k_new", k);

            // r'0 = sqrt(p1 * sqrt((k * p1) / p0) / sqrt(p0 ** 2 + p1 ** 2))
            uint256 c = FullMath.mulDiv(k, p1, p0);
            uint256 d = p0 * p0 + p1 * p1;

            trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
        }
        trustedReserve0 = trustedReserve0 / (1e18 / 10 ** decimals0);
        // r1' = (r0' * p0) / p1
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        assertApproxEqAbs(trustedReserve0, initReserve0, (10 ** decimals0) - 2);
        assertApproxEqAbs(trustedReserve1, initReserve1, (10 ** decimals1) - 2);
        emit log_named_uint("trusted0_", trustedReserve0);
        emit log_named_uint("trusted1_", trustedReserve1);
        emit log_named_uint("k_calc", getK(trustedReserve0, trustedReserve1, 10 ** decimals0, 10 ** decimals1));

        {
            uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue / 10 ** (18 - decimals0);
            uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue / 10 ** (18 - decimals1);

            uint256 k = getK(reserve0_, reserve1_, 10 ** decimals0, 10 ** decimals1);

            uint256 c = FullMath.mulDiv(k, p0, p1);
            uint256 d = p0.mulDivUp(p0, 1e18) + p1.mulDivUp(p1, 1e18);

            trustedReserve1 = FixedPointMathLib.sqrt(p0 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e18, c, d)));
        }
        trustedReserve1 = trustedReserve1 / (1e18 / 10 ** decimals1);
        // r0' = (r1' * p1) / p0
        trustedReserve0 = FullMath.mulDiv(
            trustedReserve1, rateUnderlyingAssetsToUsd[1].assetValue, rateUnderlyingAssetsToUsd[0].assetValue
        );
        emit log_named_uint("trusted0__", trustedReserve0);
        emit log_named_uint("trusted1__", trustedReserve1);
        emit log_named_uint("k_calc_", getK(trustedReserve0, trustedReserve1, 10 ** decimals0, 10 ** decimals1));
    }
}
