/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentBalances" of contract "StakingModule".
 */
contract GetCurrentBalances_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Success_getCurrentBalances_ZeroTotalSupply(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 tokenId,
        address asset
    ) public {
        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, tokenId);

        // And: totalStaked is zero.
        stakingModule.setTotalStaked(asset, 0);

        // When : Calling _getCurrentBalances().
        (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardPosition) =
            stakingModule.getCurrentBalances(positionState);

        // Then : It should return the correct values
        assertEq(currentRewardPerToken, 0);
        assertEq(totalStaked_, 0);
        assertEq(currentRewardPosition, 0);
    }

    function testFuzz_Success_getCurrentBalances_NonZeroTotalSupply_ZeroBalanceOf(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 tokenId,
        address asset
    ) public {
        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, tokenId);

        // And: totalSupply is non-zero.
        vm.assume(assetState.totalStaked > 0);

        // And: Account balance is zero.
        stakingModule.setAmountStakedForPosition(tokenId, 0);

        // When : Calling _getCurrentBalances()
        (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardPosition) =
            stakingModule.getCurrentBalances(positionState);

        // Then : It should return the correct value
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint256 rewardPerToken =
            assetState.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetState.totalStaked);

        assertEq(currentRewardPerToken, rewardPerToken);
        assertEq(totalStaked_, assetState.totalStaked);
        assertEq(currentRewardPosition, 0);
    }

    function testFuzz_Success_getCurrentBalances_NonZeroTotalSupply_NonZeroBalanceOf(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 tokenId,
        address asset
    ) public {
        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, tokenId);

        // And: Account balance is zero. (-> totalSupply is non-zero)
        vm.assume(positionState.amountStaked > 0);

        // When : Calling _getCurrentBalances()
        (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardPosition) =
            stakingModule.getCurrentBalances(positionState);

        // Then : It should return the correct value
        uint256 deltaRewardGlobal = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint256 rewardPerToken =
            assetState.lastRewardPerTokenGlobal + deltaRewardGlobal.mulDivDown(1e18, assetState.totalStaked);
        uint256 deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        uint256 currentRewardPosition_ =
            positionState.lastRewardPosition + uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);

        assertEq(currentRewardPerToken, rewardPerToken);
        assertEq(totalStaked_, assetState.totalStaked);
        assertEq(currentRewardPosition, currentRewardPosition_);
    }
}
