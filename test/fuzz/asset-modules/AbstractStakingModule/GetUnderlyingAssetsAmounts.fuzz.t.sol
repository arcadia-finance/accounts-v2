/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, Constants } from "./_AbstractStakingModule.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../src/asset-modules/Stargate-Finance/StargateAssetModule.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "StakingModule2".
 */
contract GetUnderlyingAssetsAmounts_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    using FixedPointMathLib for uint112;
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
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
        stakingModule.setAssetInPosition(underLyingAsset, positionId);
        stakingModule.setAmountStakedForPosition(positionId, amountStaked);
        stakingModule.setTotalStakedForAsset(underLyingAsset, amountStaked);

        // Avoid stack too deep
        uint96 positionIdStack = positionId;

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stakingModule.getKeyFromAsset(underLyingAsset, 0);
        underlyingAssetKeys[1] = stakingModule.getKeyFromAsset(address(stakingModule.REWARD_TOKEN()), 0);
        bytes32 assetKey = stakingModule.getKeyFromAsset(address(stakingModule), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakingModule.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 1, underlyingAssetKeys);

        // Then : Asset amounts returned should be correct.
        assertEq(underlyingAssetsAmounts[0], amountStaked);
        assertEq(underlyingAssetsAmounts[1], stakingModule.rewardOf(positionIdStack));

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsZero(uint256 positionId, address underLyingAsset)
        public
    {
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stakingModule.getKeyFromAsset(underLyingAsset, 0);
        underlyingAssetKeys[1] = stakingModule.getKeyFromAsset(address(stakingModule.REWARD_TOKEN()), 0);
        bytes32 assetKey = stakingModule.getKeyFromAsset(address(stakingModule), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakingModule.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 0, underlyingAssetKeys);

        // Then : Values returned should be correct.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
