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

    function testFuzz_Success_rewardOf(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint96 positionId,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given : Valid state
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And: State is persisted.
        setStakingModuleState(assetState, positionState, asset, positionId);

        // When : Calling rewardOf()
        uint256 currentRewardPosition = stakingModule.rewardOf(positionId);

        // Then : It should return the correct value
        uint256 deltaRewardGlobal = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 rewardPerToken;
        unchecked {
            rewardPerToken = assetState.lastRewardPerTokenGlobal
                + uint128(deltaRewardGlobal.mulDivDown(1e18, assetState.totalStaked));
        }
        uint128 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        uint256 currentRewardPosition_ =
            positionState.lastRewardPosition + uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);

        assertEq(currentRewardPosition, currentRewardPosition_);
    }
}
