/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test, Constants } from "./_AbstractStakingAM.fuzz.t.sol";

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "StakingAM".
 */
contract GetUnderlyingAssetsAmounts_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountGreaterThan0(
        uint96 positionId,
        uint128 amountStaked,
        uint128 pendingEmissions,
        address underLyingAsset
    ) public {
        // And : pendingEmissions is smaller than type(uint128).max / 1e18
        pendingEmissions = uint128(bound(pendingEmissions, 0, type(uint128).max / 1e18));

        // And : Set valid state in AM
        stakingAM.setAssetInPosition(underLyingAsset, positionId);
        stakingAM.setAmountStakedForPosition(positionId, amountStaked);
        stakingAM.setTotalStakedForAsset(underLyingAsset, amountStaked);

        // Avoid stack too deep
        uint96 positionIdStack = positionId;

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stakingAM.getKeyFromAsset(underLyingAsset, 0);
        underlyingAssetKeys[1] = stakingAM.getKeyFromAsset(address(stakingAM.REWARD_TOKEN()), 0);
        bytes32 assetKey = stakingAM.getKeyFromAsset(address(stakingAM), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakingAM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 1, underlyingAssetKeys);

        // Then : Asset amounts returned should be correct.
        assertEq(underlyingAssetsAmounts[0], amountStaked);
        assertEq(underlyingAssetsAmounts[1], stakingAM.rewardOf(positionIdStack));

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsZero(uint256 positionId, address underLyingAsset)
        public
    {
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stakingAM.getKeyFromAsset(underLyingAsset, 0);
        underlyingAssetKeys[1] = stakingAM.getKeyFromAsset(address(stakingAM.REWARD_TOKEN()), 0);
        bytes32 assetKey = stakingAM.getKeyFromAsset(address(stakingAM), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakingAM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 0, underlyingAssetKeys);

        // Then : Values returned should be correct.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
