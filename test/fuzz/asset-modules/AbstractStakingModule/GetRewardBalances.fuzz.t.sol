/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "_getRewardBalances" of contract "StakingModule".
 */
contract GetRewardBalances_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Success_getRewardBalances_ZeroTotalStaked(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Add an asset and reward token pair
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // And: totalStaked is zero.
        stakingModule.setTotalStaked(asset, 0);
        assetState.totalStaked = 0;

        // When : Calling _getRewardBalances().
        StakingModule.AssetState memory assetState_ = StakingModule.AssetState({
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            lastRewardGlobal: assetState.lastRewardGlobal,
            totalStaked: assetState.totalStaked
        });
        StakingModule.PositionState memory positionState_;
        (assetState_, positionState_) = stakingModule.getRewardBalances(assetState_, positionState);

        // Then : It should return the correct values
        assertEq(positionState_.asset, positionState.asset);
        assertEq(positionState_.amountStaked, positionState.amountStaked);
        assertEq(positionState_.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(positionState_.lastRewardPosition, positionState.lastRewardPosition);

        assertEq(assetState_.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(assetState_.lastRewardGlobal, assetState.lastRewardGlobal);
        assertEq(assetState_.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_getRewardBalances_TotalStakedGreaterThan0(
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Add an asset and reward token pair
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // And: Amount staked for position is > 0. (-> totalStaked is non-zero)
        vm.assume(positionState.amountStaked > 0);

        // When : Calling _getRewardBalances().
        StakingModule.AssetState memory assetState_ = StakingModule.AssetState({
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            lastRewardGlobal: assetState.lastRewardGlobal,
            totalStaked: assetState.totalStaked
        });
        StakingModule.PositionState memory positionState_;
        (assetState_, positionState_) = stakingModule.getRewardBalances(assetState_, positionState);

        // Then : It should return the correct values
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

        // Then : It should return the correct values
        assertEq(positionState_.asset, positionState.asset);
        assertEq(positionState_.amountStaked, positionState.amountStaked);
        assertEq(positionState_.lastRewardPerTokenPosition, rewardPerToken);
        assertEq(positionState_.lastRewardPosition, currentRewardPosition_);

        assertEq(assetState_.lastRewardPerTokenGlobal, rewardPerToken);
        assertEq(assetState_.lastRewardGlobal, assetState.currentRewardGlobal);
        assertEq(assetState_.totalStaked, assetState.totalStaked);
    }
}
