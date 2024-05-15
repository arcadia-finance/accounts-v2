/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, ERC20Mock, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "claimRewards" of contract "WrappedAM".
 */
contract ClaimRewards_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_claimRewards_NotOwner(address owner, address randomAddress, uint96 positionId) public {
        // Given: randomAddress is not the owner.
        vm.assume(owner != randomAddress);

        // Given : Owner of positionId is not randomAddress
        wrappedAM.setOwnerOfPositionId(owner, positionId);

        // When : randomAddress calls claimRewards for positionId
        // Then : It should revert as randomAddress is not owner of the positionId
        vm.startPrank(randomAddress);
        vm.expectRevert(WrappedAM.NotOwner.selector);
        wrappedAM.claimRewards(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_claimRewards_NonZeroReward(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address asset,
        uint128 totalWrapped,
        uint96 positionId,
        uint8 rewardDecimals,
        address underlyingAsset,
        address account
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : Valid state
        (
            AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[] memory positionStatePerReward_,
            uint128 totalWrapped_
        ) = givenValidWrappedAMState(
            castArrayStaticToDynamicAssetAndReward(assetAndRewardState),
            positionState,
            castArrayStaticToDynamicPositionPerReward(positionStatePerReward),
            totalWrapped
        );

        // And : Two reward tokens
        rewardDecimals = uint8(bound(rewardDecimals, 0, 18));
        address[] memory rewards = new address[](2);
        rewards[0] = address(new ERC20Mock("Reward", "RWD", rewardDecimals));
        rewards[1] = address(new ERC20Mock("Reward", "RWD", rewardDecimals));

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            rewards,
            positionId,
            totalWrapped_,
            underlyingAsset
        );

        // And : owner of ERC721 positionId is Account
        wrappedAM.setOwnerOfPositionId(account, positionId);

        // And : The claim function on the external staking contract is not implemented, thus we fund the wrappedAM with reward tokens that should be transferred.
        uint256[] memory currentRewardsPosition = wrappedAM.rewardsOf(positionId);
        assertEq(currentRewardsPosition.length, 2);

        // And rewards are non-zero.
        vm.assume(currentRewardsPosition[0] > 0);
        vm.assume(currentRewardsPosition[1] > 0);

        mintERC20TokenTo(rewards[0], address(wrappedAM), currentRewardsPosition[0]);
        mintERC20TokenTo(rewards[1], address(wrappedAM), currentRewardsPosition[1]);

        // Stack too deep
        address assetStack = asset;
        uint96 positionIdStack = positionId;
        uint256[] memory currentRewardGlobalStack = new uint256[](2);
        currentRewardGlobalStack[0] = assetAndRewardState_[0].currentRewardGlobal;
        currentRewardGlobalStack[1] = assetAndRewardState_[1].currentRewardGlobal;
        uint128[] memory lastRewardPerTokenGlobalStack = new uint128[](2);
        lastRewardPerTokenGlobalStack[0] = assetAndRewardState_[0].lastRewardPerTokenGlobal;
        lastRewardPerTokenGlobalStack[1] = assetAndRewardState_[1].lastRewardPerTokenGlobal;

        // When : Account calls claimReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit WrappedAM.RewardPaid(positionId, rewards[0], uint128(currentRewardsPosition[0]));
        emit WrappedAM.RewardPaid(positionId, rewards[1], uint128(currentRewardsPosition[1]));
        uint256[] memory rewards_ = wrappedAM.claimRewards(positionIdStack);
        vm.stopPrank();

        // Then : claimed rewards are returned.
        assertEq(rewards_[0], currentRewardsPosition[0]);
        assertEq(rewards_[1], currentRewardsPosition[1]);

        // And : Account should have received the reward tokens.
        assertEq(currentRewardsPosition[0], ERC20Mock(rewards[0]).balanceOf(account));
        assertEq(currentRewardsPosition[1], ERC20Mock(rewards[1]).balanceOf(account));

        // And: Position state per reward and lastRewardPerTokenGlobal should be updated correctly.
        for (uint256 i; i < rewards_.length; ++i) {
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(positionIdStack, rewards[i]);
            uint128 lastRewardPerTokenGlobal = wrappedAM.lastRewardPerTokenGlobal(assetStack, rewards[i]);
            uint128 currentRewardPerToken;
            unchecked {
                currentRewardPerToken = lastRewardPerTokenGlobalStack[i]
                    + uint128(currentRewardGlobalStack[i].mulDivDown(1e18, totalWrapped_));
            }
            assertEq(lastRewardPerTokenPosition, currentRewardPerToken);
            assertEq(lastRewardPosition, 0);
            assertEq(lastRewardPerTokenGlobal, currentRewardPerToken);
        }
    }

    function testFuzz_Success_claimRewards_ZeroReward(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address asset,
        uint128 totalWrapped,
        uint96 positionId,
        uint8 rewardDecimals,
        address underlyingAsset,
        address account
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : Valid state
        (
            AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[] memory positionStatePerReward_,
            uint128 totalWrapped_
        ) = givenValidWrappedAMState(
            castArrayStaticToDynamicAssetAndReward(assetAndRewardState),
            positionState,
            castArrayStaticToDynamicPositionPerReward(positionStatePerReward),
            totalWrapped
        );

        // And : Two reward tokens
        rewardDecimals = uint8(bound(rewardDecimals, 0, 18));
        address[] memory rewards = new address[](2);
        rewards[0] = address(new ERC20Mock("Reward", "RWD", rewardDecimals));
        rewards[1] = address(new ERC20Mock("Reward", "RWD", rewardDecimals));

        // And : Reward is zero
        for (uint256 i; i < rewards.length; ++i) {
            positionStatePerReward_[i].lastRewardPosition = 0;
            positionStatePerReward_[i].lastRewardPerTokenPosition = assetAndRewardState_[i].lastRewardPerTokenGlobal;
            assetAndRewardState_[i].currentRewardGlobal = 0;
        }

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            rewards,
            positionId,
            totalWrapped_,
            underlyingAsset
        );

        // Stack too deep
        address assetStack = asset;

        // And : owner of ERC721 positionId is Account
        wrappedAM.setOwnerOfPositionId(account, positionId);

        // When : Account calls claimReward()
        vm.startPrank(account);
        uint256[] memory rewards_ = wrappedAM.claimRewards(positionId);
        vm.stopPrank();

        // Then : claimed rewards are returned.
        assertEq(rewards_.length, 2);
        assertEq(rewards_[0], 0);
        assertEq(rewards_[1], 0);

        // And : Account should not have received the reward tokens.
        assertEq(0, ERC20Mock(rewards[0]).balanceOf(account));
        assertEq(0, ERC20Mock(rewards[1]).balanceOf(account));

        // And: Position state per reward and lastRewardPerTokenGlobal should be updated correctly.
        for (uint256 i; i < rewards_.length; ++i) {
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(positionId, rewards[i]);
            uint128 lastRewardPerTokenGlobal = wrappedAM.lastRewardPerTokenGlobal(assetStack, rewards[i]);
            assertEq(lastRewardPerTokenPosition, assetAndRewardState_[i].lastRewardPerTokenGlobal);
            assertEq(lastRewardPosition, 0);
            assertEq(lastRewardPerTokenGlobal, assetAndRewardState_[i].lastRewardPerTokenGlobal);
        }
    }
}
