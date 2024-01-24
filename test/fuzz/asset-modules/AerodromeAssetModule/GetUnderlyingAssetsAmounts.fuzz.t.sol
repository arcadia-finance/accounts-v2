/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test, Constants } from "./_AerodromeAssetModule.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeAssetModule.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "AerodromeAssetModule".
 */
contract GetUnderlyingAssetsAmounts_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    using FixedPointMathLib for uint112;
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIs0(
        address creditor,
        bytes32 assetKey,
        uint256 amount,
        bytes32[] memory underlyingAssetKeys
    ) public {
        // Given : amount is 0
        amount = 0;

        // When : Calling getUnderlyingAssetsAmounts
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            aerodromeAssetModule.getUnderlyingAssetsAmounts(creditor, assetKey, amount, underlyingAssetKeys);
        // Then : It should return correct values
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(underlyingAssetsAmounts[2], 0);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsOne(
        uint96 positionId,
        uint128 amountStaked,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint128 earned
    ) public {
        // Given : Inputs are valid
        vm.assume(amountStaked > 0);
        totalSupply = bound(totalSupply, amountStaked, type(uint256).max);
        reserve0 = bound(reserve0, 1, type(uint128).max);
        reserve1 = bound(reserve1, 1, type(uint128).max);

        // Given : Amount is 1
        uint256 amount = 1;

        // And : Valid underlyingAssetKeys
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = aerodromeAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);
        underlyingAssetKeys[1] = aerodromeAssetModule.getKeyFromAsset(address(mockERC20.stable1), 0);
        underlyingAssetKeys[2] = aerodromeAssetModule.getKeyFromAsset(address(aerodromeAssetModule.rewardToken()), 0);

        // And : Reserves are set in pool
        pool.setReserves(reserve0, reserve1);

        // And : TotalSupply is set in pool
        pool.setTotalSupply(totalSupply);

        // And : Asset to gauge is set in the AM
        aerodromeAssetModule.setAssetToGauge(address(pool), address(gauge));

        // And : Set info in position
        aerodromeAssetModule.setAssetInPosition(address(pool), positionId);
        aerodromeAssetModule.setAmountStakedForPosition(positionId, amountStaked);

        // And : Set info for asset
        aerodromeAssetModule.setTotalStakedForAsset(address(pool), amountStaked);

        // And : Set earned for address in gauge
        gauge.setEarnedForAddress(address(aerodromeAssetModule), earned);

        bytes32 assetKey = aerodromeAssetModule.getKeyFromAsset(address(aerodromeAssetModule), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        aerodromeAssetModule.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, amount, underlyingAssetKeys);

        // Then : Values returned should be correct.
        assertEq(underlyingAssetsAmounts[0], reserve0.mulDivDown(amountStaked, totalSupply));
        assertEq(underlyingAssetsAmounts[1], reserve1.mulDivDown(amountStaked, totalSupply));
        assertEq(underlyingAssetsAmounts[2], aerodromeAssetModule.rewardOf(positionId));

        // We do not fuzz rates here as returned rate is covered by our testing of _getRateUnderlyingAssetsToUsd() for derivedAssetModule.
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd_ =
            aerodromeAssetModule.getRateUnderlyingAssetsToUsd(address(creditorToken1), underlyingAssetKeys);

        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd_[0].assetValue);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, rateUnderlyingAssetsToUsd_[1].assetValue);
        assertEq(rateUnderlyingAssetsToUsd[2].assetValue, rateUnderlyingAssetsToUsd_[2].assetValue);
    }
}
