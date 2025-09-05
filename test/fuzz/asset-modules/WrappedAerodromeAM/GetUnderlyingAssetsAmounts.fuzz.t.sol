/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Pool } from "../../../utils/mocks/Aerodrome/AeroPoolMock.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "WrappedAerodromeAM".
 */
contract GetUnderlyingAssetsAmounts_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountGreaterThan0(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1,
        uint96 positionId,
        uint256 amount
    ) public {
        // Given : Valid aeroPool.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);

        // And : amount is greater than zero.
        amount = bound(amount, 1, type(uint256).max);

        // And : Valid state.
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);

        // And: State is persisted.
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);

        bytes32 assetKey = wrappedAerodromeAM.getKeyFromAsset(address(wrappedAerodromeAM), positionId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool), 0);
        underlyingAssetKeys[1] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token0()), 0);
        underlyingAssetKeys[2] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token1()), 0);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        wrappedAerodromeAM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, amount, underlyingAssetKeys);

        // Then : Asset amounts returned should be correct.
        assertEq(underlyingAssetsAmounts[0], positionState.amountWrapped);
        (uint256 fee0_, uint256 fee1_) = wrappedAerodromeAM.feesOf(positionId);
        assertEq(underlyingAssetsAmounts[1], fee0_);
        assertEq(underlyingAssetsAmounts[2], fee1_);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsZero(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1,
        uint96 positionId
    ) public {
        // Given : Valid aeroPool.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);

        // And: State is persisted.
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);

        bytes32 assetKey = wrappedAerodromeAM.getKeyFromAsset(address(wrappedAerodromeAM), positionId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool), 0);
        underlyingAssetKeys[1] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token0()), 0);
        underlyingAssetKeys[2] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token1()), 0);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            wrappedAerodromeAM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 0, underlyingAssetKeys);

        // Then : Values returned should be correct.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(underlyingAssetsAmounts[2], 0);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
