/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test, StakingAM } from "./_AbstractStakingAM.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "claimReward" of contract "StakingAM".
 */
contract ClaimReward_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimReward_NotOwner(address owner, address randomAddress, uint96 positionId) public {
        // Given: randomAddress is not the owner.
        vm.assume(owner != randomAddress);

        // Given : Owner of positionId is not randomAddress
        stakingAM.setOwnerOfPositionId(owner, positionId);

        // When : randomAddress calls claimReward for positionId
        // Then : It should revert as randomAddress is not owner of the positionId
        vm.startPrank(randomAddress);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakingAM.claimReward(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_claimReward_NonZeroReward(
        address account,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint8 assetDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : owner of ERC721 positionId is Account
        stakingAM.setOwnerOfPositionId(account, positionId);

        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given: Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, asset, positionId);

        // Given : The claim function on the external staking contract is not implemented, thus we fund the stakingAM with reward tokens that should be transferred.
        uint256 currentRewardPosition = stakingAM.rewardOf(positionId);

        // And reward is non-zero.
        vm.assume(currentRewardPosition > 0);

        mintERC20TokenTo(address(stakingAM.REWARD_TOKEN()), address(stakingAM), currentRewardPosition);

        // When : Account calls claimReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(stakingAM.REWARD_TOKEN()), uint128(currentRewardPosition));
        uint256 rewards = stakingAM.claimReward(positionId);
        vm.stopPrank();

        // Then : claimed rewards are returned.
        assertEq(rewards, currentRewardPosition);

        // And : Account should have received the reward tokens.
        assertEq(currentRewardPosition, stakingAM.REWARD_TOKEN().balanceOf(account));

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_claimReward_ZeroReward(
        address account,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint8 assetDecimals
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : owner of ERC721 positionId is Account
        stakingAM.setOwnerOfPositionId(account, positionId);

        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given: Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = assetState.lastRewardGlobal;

        // And: State is persisted.
        setStakingAMState(assetState, positionState, asset, positionId);

        // When : Account calls claimReward()
        vm.startPrank(account);
        uint256 rewards = stakingAM.claimReward(positionId);
        vm.stopPrank();

        // Then : No claimed rewards are returned.
        assertEq(rewards, 0);

        // And : Account should have not received reward tokens.
        assertEq(stakingAM.REWARD_TOKEN().balanceOf(account), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }
}
