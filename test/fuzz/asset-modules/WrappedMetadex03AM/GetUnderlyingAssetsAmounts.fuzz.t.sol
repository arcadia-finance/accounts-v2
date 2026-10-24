/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "WrappedMetadex03AM".
 */
contract GetUnderlyingAssetsAmounts_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
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
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        setAMState(metadex03Pool, positionId, poolState, positionState);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);

        // And: The asset key of the position and the keys of its underlying assets.
        bytes32 assetKey = wrappedMetadex03AM.getKeyFromAsset(address(wrappedMetadex03AM), positionId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool), 0);
        underlyingAssetKeys[1] = wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool.token0()), 0);
        underlyingAssetKeys[2] = wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool.token1()), 0);

        // When: The underlying amounts are read for an amount of zero positions.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            wrappedMetadex03AM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 0, underlyingAssetKeys);

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
        metadex03Pool = createPoolMetadex03(address(asset0), address(asset1), stable);
        (poolState, positionState, fee0, fee1) = givenValidAMState(poolState, positionState, fee0, fee1);
        setAMState(metadex03Pool, positionId, poolState, positionState);
        setClaimables(metadex03Pool, address(wrappedMetadex03AM), fee0, fee1);
        deal(metadex03Pool.token0(), metadex03Pool.poolFees(), fee0, true);
        deal(metadex03Pool.token1(), metadex03Pool.poolFees(), fee1, true);

        // And: The amount of positions is non-zero.
        vm.assume(amount != 0);

        // And: The asset key of the position and the keys of its underlying assets.
        bytes32 assetKey = wrappedMetadex03AM.getKeyFromAsset(address(wrappedMetadex03AM), positionId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool), 0);
        underlyingAssetKeys[1] = wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool.token0()), 0);
        underlyingAssetKeys[2] = wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool.token1()), 0);

        // When: The underlying amounts are read.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = wrappedMetadex03AM.getUnderlyingAssetsAmounts(
            address(creditorToken1), assetKey, amount, underlyingAssetKeys
        );

        // Then: The wrapped liquidity and both claimable fees are returned.
        assertEq(underlyingAssetsAmounts[0], positionState.amountWrapped);
        (uint256 fee0_, uint256 fee1_) = wrappedMetadex03AM.feesOf(positionId);
        assertEq(underlyingAssetsAmounts[1], fee0_);
        assertEq(underlyingAssetsAmounts[2], fee1_);

        // And: No rates of the underlying assets are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
