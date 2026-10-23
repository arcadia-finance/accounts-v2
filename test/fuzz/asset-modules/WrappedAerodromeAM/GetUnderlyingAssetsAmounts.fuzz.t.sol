/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

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

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsZero(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1,
        uint96 positionId
    ) public {
        // Given: A pool with an arbitrary wrapped state and pending fees.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);

        // And: The asset key of the position and the keys of its underlying assets.
        bytes32 assetKey = wrappedAerodromeAM.getKeyFromAsset(address(wrappedAerodromeAM), positionId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool), 0);
        underlyingAssetKeys[1] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token0()), 0);
        underlyingAssetKeys[2] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token1()), 0);

        // When: The underlying amounts are read for an amount of zero positions.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            wrappedAerodromeAM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 0, underlyingAssetKeys);

        // Then: All three underlying amounts are zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(underlyingAssetsAmounts[2], 0);

        // And: No rates of the underlying assets are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountGreaterThan0(
        bool stable,
        WrappedAerodromeAM.PoolState memory poolState,
        WrappedAerodromeAM.PositionState memory positionState,
        uint256 fee0,
        uint256 fee1,
        uint96 positionId,
        uint256 amount
    ) public {
        // Given: A pool with a valid wrapped state.
        aeroPool = createPoolAerodrome(address(asset0), address(asset1), stable);
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);
        setAMState(aeroPool, positionId, poolState, positionState);
        aeroPool.setClaimables(address(wrappedAerodromeAM), fee0, fee1);
        deal(aeroPool.token0(), aeroPool.poolFees(), fee0, true);
        deal(aeroPool.token1(), aeroPool.poolFees(), fee1, true);

        // And: The amount of positions is non-zero.
        vm.assume(amount != 0);

        // And: The asset key of the position and the keys of its underlying assets.
        bytes32 assetKey = wrappedAerodromeAM.getKeyFromAsset(address(wrappedAerodromeAM), positionId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool), 0);
        underlyingAssetKeys[1] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token0()), 0);
        underlyingAssetKeys[2] = wrappedAerodromeAM.getKeyFromAsset(address(aeroPool.token1()), 0);

        // When: The underlying amounts are read.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = wrappedAerodromeAM.getUnderlyingAssetsAmounts(
            address(creditorToken1), assetKey, amount, underlyingAssetKeys
        );

        // Then: The wrapped liquidity and both claimable fees are returned.
        assertEq(underlyingAssetsAmounts[0], positionState.amountWrapped);
        (uint256 fee0_, uint256 fee1_) = wrappedAerodromeAM.feesOf(positionId);
        assertEq(underlyingAssetsAmounts[1], fee0_);
        assertEq(underlyingAssetsAmounts[2], fee1_);

        // And: No rates of the underlying assets are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
