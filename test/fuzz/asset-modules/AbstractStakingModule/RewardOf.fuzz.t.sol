/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "rewardOf" of contract "StakingModule".
 */
contract RewardOf_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_rewardOf_ZeroBalanceOf(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 tokenId,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Add an asset and reward token pair
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, tokenId);

        // And: Account balance is zero.
        stakingModule.setAmountStakedForPosition(tokenId, 0);

        // When : Calling rewardOf()
        uint256 currentRewardPosition = stakingModule.rewardOf(tokenId);

        // Then : It should return zero.
        assertEq(currentRewardPosition, 0);
    }

    function testFuzz_Success_rewardOf_NonZeroBalanceOf(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 tokenId,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Add an asset and reward token pair
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, tokenId);

        // And: Account balance is non zero.
        vm.assume(positionState.amountStaked > 0);

        // When : Calling rewardOf()
        uint256 currentRewardPosition = stakingModule.rewardOf(tokenId);

        // Then : It should return the correct value
        uint256 deltaRewardGlobal = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint256 rewardPerToken =
            assetState.lastRewardPerTokenGlobal + deltaRewardGlobal.mulDivDown(1e18, assetState.totalStaked);
        uint256 deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        uint256 currentRewardPosition_ =
            positionState.lastRewardPosition + uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);

        assertEq(currentRewardPosition, currentRewardPosition_);
    }
}
