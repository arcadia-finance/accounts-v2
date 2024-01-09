/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, Constants } from "./_StargateAssetModule.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../src/asset-modules/StargateAssetModule.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "StargateAssetModule".
 */
contract GetUnderlyingAssetsAmounts_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    using FixedPointMathLib for uint112;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    /*     function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    } */

    /*     function testFuzz_Success_getUnderlyingAssetsAmounts_LiquidityGreaterThanZero(
        uint256 tokenId,
        uint112 assetAmount,
        uint128 totalLiquidity,
        uint256 convertRate,
        uint128 totalSupply
    ) public {
        // Given : convertRate should be between 1 and 10**18.
        convertRate = bound(convertRate, 0, 18);
        convertRate = 10 ** convertRate;

        // And : totalSupply > 0
        vm.assume(totalSupply > 0);

        // And : totalLiquidity should be at least equal to totalSupply (invariant)
        totalLiquidity = uint128(bound(totalLiquidity, totalSupply, type(uint128).max));

        // And : Avoid overflow in calculations
        vm.assume(uint256(assetAmount) * totalLiquidity <= type(uint256).max / convertRate);

        // And : Set valid state on the pool.
        poolMock.setState(address(mockERC20.token1), totalLiquidity, totalSupply, convertRate);

        // Given : The mapping from assetKey to the pool is set.
        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), tokenId);
        stargateAssetModule.setAssetKeyToPool(assetKey, address(poolMock));

        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] = stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        stargateAssetModule.getUnderlyingAssetsAmounts(
            address(creditorToken1), assetKey, assetAmount, underlyingAssetKeys
        );

        // Then : Values returned should be correct.
        uint256 computedUnderlyingAssetAmount = assetAmount.mulDivDown(totalLiquidity, totalSupply);
        computedUnderlyingAssetAmount *= convertRate;

        // We do not fuzz rates here as returned rate is covered by our testing of _getRateUnderlyingAssetsToUsd() for derivedAssetModule.
        uint256 expectedRateToken1ToUsd = rates.token1ToUsd * 10 ** (18 - Constants.tokenOracleDecimals);

        assertEq(underlyingAssetsAmounts[0], computedUnderlyingAssetAmount);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, expectedRateToken1ToUsd);
    } */

    /*     function testFuzz_Success_getUnderlyingAssetsAmounts_ZeroTotalLiquidity(
        uint256 tokenId,
        uint112 assetAmount,
        uint128 totalLiquidity,
        uint256 convertRate,
        uint128 totalSupply
    ) public {
        // Given : convertRate should be between 1 and 10**18.
        convertRate = bound(convertRate, 0, 18);
        convertRate = 10 ** convertRate;

        // And : totalSupply > 0
        vm.assume(totalSupply > 0);

        // And : totalLiquidity and totalSupply are 0
        totalLiquidity = 0;
        totalSupply = 0;

        // And : Set valid state on the pool.
        poolMock.setState(address(mockERC20.token1), totalLiquidity, totalSupply, convertRate);

        // Given : The mapping from assetKey to the pool is set.
        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), tokenId);
        stargateAssetModule.setAssetKeyToPool(assetKey, address(poolMock));

        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] = stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        stargateAssetModule.getUnderlyingAssetsAmounts(
            address(creditorToken1), assetKey, assetAmount, underlyingAssetKeys
        );

        // Then : Values returned should be correct.
        // We do not fuzz rates here as returned rate is covered by our testing of _getRateUnderlyingAssetsToUsd() for derivedAssetModule.
        uint256 expectedRateToken1ToUsd = rates.token1ToUsd * 10 ** (18 - Constants.tokenOracleDecimals);

        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, expectedRateToken1ToUsd);
    } */
}
