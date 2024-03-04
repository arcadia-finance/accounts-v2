/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import {
    AerodromeVolatileAM_Fuzz_Test, FixedPointMathLib, FullMath, ERC20Mock
} from "./_AerodromeVolatileAM.fuzz.t.sol";

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { AerodromeVolatileAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "AerodromeVolatileAM".
 */
contract GetUnderlyingAssetsAmounts_AerodromeVolatileAM_Fuzz_Test is AerodromeVolatileAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeVolatileAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_getUnderlyingAssetsAmounts_SupplyIsZero(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = initAndSetValidStateInPoolFixture(testVars);

        // And : totalSupply is zero
        uint256 totalSupply = 0;
        stdstore.target(address(pool)).sig(pool.totalSupply.selector).checked_write(totalSupply);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts
        // Then : It should revert
        vm.expectRevert(AerodromeVolatileAM.ZeroSupply.selector);
        aeroVolatileAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_SupplyGreaterThan0_Volatile(TestVariables memory testVars)
        public
    {
        // Given : Valid state
        testVars = initAndSetValidStateInPoolFixture(testVars);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts()
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        aeroVolatileAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );

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
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_TestFormulas_Volatile() public {
        uint256 initReserve0 = 1_111_111 * 1e18;
        uint256 initReserve1 = 1_111_111 * 1e6;

        // Given : Deploy two tokens for the new Aerodrome tokenPair
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", 18);
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", 6);

        deployAerodromeVolatileFixture(address(token0), address(token1));

        // And : The tokens of the pool are added to the Arcadia protocol with price 1e18
        addUnderlyingTokenToArcadia(address(token0), int256(1e18));
        addUnderlyingTokenToArcadia(address(token1), int256(1e18));

        deal(address(token0), address(pool), initReserve0);
        deal(address(token1), address(pool), initReserve1);

        // And : A first position is minted
        pool.mint(users.accountOwner);

        uint256 amount0In = 990_999 * 1e18;
        uint256 amount1Out = pool.getAmountOut(amount0In, address(token0));
        emit log_named_uint("amount1 out", amount1Out);

        // And : We swap tokens (but do not change relative price)
        deal(address(token0), users.accountOwner, amount0In);
        vm.prank(users.accountOwner);
        token0.transfer(address(pool), amount0In);

        pool.swap(0, amount1Out, users.accountOwner, "");

        (uint256 reserve0_, uint256 reserve1_,) = pool.getReserves();
        emit log_named_uint("untrusted 0", reserve0_);
        emit log_named_uint("untrusted 1", reserve1_);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));

        (, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            aeroVolatileAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 100, underlyingAssetKeys);

        uint256 k = reserve0_ * reserve1_;

        // r0' = sqrt((p1 * k) / p0)
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(
            FullMath.mulDiv(rateUnderlyingAssetsToUsd[1].assetValue, k, rateUnderlyingAssetsToUsd[0].assetValue)
        );

        emit log_named_uint("trusted0", trustedReserve0);

        // r1' = (r0' * p0) / p1
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue
        );

        emit log_named_uint("trusted1", trustedReserve1);

        // Max diff is less than 1, due to rounding diffs, minor
        // Diff does not increase with increase of amount swapped
        assertApproxEqAbs(trustedReserve0, initReserve0, 1e12);
        assertEq(trustedReserve1, initReserve1);
    }
}
