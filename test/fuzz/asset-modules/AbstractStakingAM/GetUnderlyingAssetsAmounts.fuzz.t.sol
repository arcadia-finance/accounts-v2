/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";
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
        uint128 otherStaked,
        uint128 pendingEmissions,
        address underLyingAsset
    ) public {
        uint256 expectedReward;
        {
            // Given : The position and the other stakers together fit the uint128 total staked of the Asset.
            // forge-lint: disable-next-item(unsafe-typecast)
            otherStaked = uint128(bound(otherStaked, 0, type(uint128).max - amountStaked));

            // And : Set valid state in AM
            stakingAM.setAssetInPosition(underLyingAsset, positionId);
            stakingAM.setAmountStakedForPosition(positionId, amountStaked);
            stakingAM.setTotalStakedForAsset(underLyingAsset, amountStaked + otherStaked);
            stakingAM.setActualRewardBalance(underLyingAsset, pendingEmissions);

            // And : The pending emissions are shared over the total staked.
            StakingAMStateForAsset memory assetState;
            assetState.totalStaked = amountStaked + otherStaked;
            assetState.currentRewardGlobal = pendingEmissions;
            expectedReward = uint256(currentRewardPerTokenGlobal(assetState)) * amountStaked / 1e18;
        }

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stakingAM.getKeyFromAsset(underLyingAsset, 0);
        underlyingAssetKeys[1] = stakingAM.getKeyFromAsset(address(stakingAM.REWARD_TOKEN()), 0);
        bytes32 assetKey = stakingAM.getKeyFromAsset(address(stakingAM), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakingAM.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 1, underlyingAssetKeys);

        // Then : Asset amounts returned should be correct.
        assertEq(underlyingAssetsAmounts[0], amountStaked);
        assertEq(underlyingAssetsAmounts[1], expectedReward);
        assertEq(underlyingAssetsAmounts[1], stakingAM.rewardOf(positionId));

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsZero(uint256 positionId, address underLyingAsset)
        public
        view
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
