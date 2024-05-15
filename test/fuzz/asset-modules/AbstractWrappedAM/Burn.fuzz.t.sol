/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, ERC20Mock, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "WrappedAM".
 */
contract Burn_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
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
    function testFuzz_Revert_burn_NotOwner(address randomAddress, uint96 positionId, address account) public {
        // Given : Owner of positionId is not the Account
        wrappedAM.setOwnerOfPositionId(randomAddress, positionId);

        // When : Calling burn()
        // Then : The function should revert as the Account is not the owner of the positionId
        vm.startPrank(account);
        vm.expectRevert(WrappedAM.NotOwner.selector);
        wrappedAM.burnPosition(positionId);
    }

    function testFuzz_Success_burn_NonZeroReward(
        address account,
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address underlyingAsset,
        uint128 totalWrapped,
        uint96 positionId
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(wrappedAM));

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

        // And : Position has a non-zero balance
        vm.assume(positionState_.amountWrapped > 0);

        // And : Given asset and rewards
        address asset = address(mockERC20.token1);
        address[] memory rewards = new address[](2);
        rewards[0] = address(mockERC20.token2);
        rewards[1] = address(mockERC20.stable1);

        // Stack too deep
        address accountStack = account;
        uint96 positionIdStack = positionId;
        address underlyingAssetStack = underlyingAsset;
        address assetStack = asset;

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            assetStack,
            rewards,
            positionIdStack,
            totalWrapped_,
            underlyingAssetStack
        );

        // And : Rewards are non-zero
        uint256[] memory currentRewards = wrappedAM.rewardsOf(positionId);
        vm.assume(currentRewards[0] > 0);
        vm.assume(currentRewards[1] > 0);

        // And : Position is minted to the Account
        wrappedAM.mintIdTo(accountStack, positionIdStack);

        // And : transfer Asset and rewardToken to wrappedAM, as _claimRewards is not implemented on abstract contract.
        mintERC20TokenTo(rewards[0], address(wrappedAM), currentRewards[0]);
        mintERC20TokenTo(rewards[1], address(wrappedAM), currentRewards[1]);
        mintERC20TokenTo(asset, address(wrappedAM), positionState_.amountWrapped);

        // Stack too deep
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardsStack =
            assetAndRewardState_;
        uint128 positionAmountStack = positionState_.amountWrapped;
        uint128 totalWrappedStack = totalWrapped_;
        address[] memory rewardsStack = rewards;

        // When : Account burns its position.
        vm.startPrank(accountStack);
        vm.expectEmit();
        emit WrappedAM.RewardPaid(positionIdStack, rewards[0], uint128(currentRewards[0]));
        emit WrappedAM.RewardPaid(positionIdStack, rewards[1], uint128(currentRewards[1]));
        emit WrappedAM.LiquidityDecreased(positionIdStack, asset, positionAmountStack);
        wrappedAM.burnPosition(positionIdStack);
        vm.stopPrank();

        // Then : Account should get the rewards and asset tokens
        assertEq(ERC20Mock(asset).balanceOf(accountStack), positionAmountStack);
        assertEq(mockERC20.token2.balanceOf(accountStack), currentRewards[0]);
        assertEq(mockERC20.stable1.balanceOf(accountStack), currentRewards[1]);

        // And : PositionId should be burned
        assertEq(wrappedAM.balanceOf(accountStack), 0);

        for (uint256 i; i < 2; ++i) {
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(positionIdStack, rewards[i]);
            assertEq(lastRewardPerTokenPosition, 0);
            assertEq(lastRewardPosition, 0);
        }

        (address customAsset, uint128 amountWrapped) = wrappedAM.positionState(positionIdStack);
        assertEq(customAsset, address(0));
        assertEq(amountWrapped, 0);

        // And : Asset state should be updated correctly
        for (uint256 i; i < 2; ++i) {
            uint256 deltaReward = assetAndRewardsStack[i].currentRewardGlobal;
            uint128 currentRewardPerToken;
            unchecked {
                currentRewardPerToken =
                    assetAndRewardsStack[i].lastRewardPerTokenGlobal + uint128(deltaReward * 1e18 / totalWrappedStack);
            }
            assertEq(wrappedAM.lastRewardPerTokenGlobal(assetStack, rewardsStack[i]), currentRewardPerToken);
        }

        assertEq(wrappedAM.assetToTotalWrapped(assetStack), totalWrappedStack - positionAmountStack);
    }

    function testFuzz_Success_burn_ZeroReward(
        address account,
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address underlyingAsset,
        uint128 totalWrapped,
        uint96 positionId
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(wrappedAM));

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

        // And : Position has a non-zero balance
        vm.assume(positionState_.amountWrapped > 0);

        // And : Given asset and rewards
        address asset = address(mockERC20.token1);
        address[] memory rewards = new address[](2);
        rewards[0] = address(mockERC20.token2);
        rewards[1] = address(mockERC20.stable1);

        // Stack too deep
        address accountStack = account;
        uint96 positionIdStack = positionId;
        address underlyingAssetStack = underlyingAsset;
        address assetStack = asset;

        // And : Rewards are zero
        for (uint256 i; i < 2; ++i) {
            assetAndRewardState_[i].currentRewardGlobal = 0;
            positionStatePerReward_[i].lastRewardPerTokenPosition = assetAndRewardState_[i].lastRewardPerTokenGlobal;
            positionStatePerReward_[i].lastRewardPosition = 0;
        }

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            assetStack,
            rewards,
            positionIdStack,
            totalWrapped_,
            underlyingAssetStack
        );

        // And : Position is minted to the Account
        wrappedAM.mintIdTo(accountStack, positionIdStack);

        // And : transfer Asset to wrappedAM, as _claimRewards is not implemented on abstract contract.
        mintERC20TokenTo(asset, address(wrappedAM), positionState_.amountWrapped);

        // Stack too deep
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardsStack =
            assetAndRewardState_;
        uint128 positionAmountStack = positionState_.amountWrapped;
        uint128 totalWrappedStack = totalWrapped_;
        address[] memory rewardsStack = rewards;

        // When : Account burns its position.
        vm.startPrank(accountStack);
        vm.expectEmit();
        emit WrappedAM.LiquidityDecreased(positionIdStack, asset, positionAmountStack);
        wrappedAM.burnPosition(positionIdStack);
        vm.stopPrank();

        // Then : Account should get the asset tokens
        assertEq(ERC20Mock(asset).balanceOf(accountStack), positionAmountStack);
        assertEq(mockERC20.token2.balanceOf(accountStack), 0);
        assertEq(mockERC20.stable1.balanceOf(accountStack), 0);

        // And : PositionId should be burned
        assertEq(wrappedAM.balanceOf(accountStack), 0);

        for (uint256 i; i < 2; ++i) {
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(positionIdStack, rewards[i]);
            assertEq(lastRewardPerTokenPosition, 0);
            assertEq(lastRewardPosition, 0);
        }

        (address customAsset, uint128 amountWrapped) = wrappedAM.positionState(positionIdStack);
        assertEq(customAsset, address(0));
        assertEq(amountWrapped, 0);

        // And : Asset state should be updated correctly
        for (uint256 i; i < 2; ++i) {
            assertEq(
                wrappedAM.lastRewardPerTokenGlobal(assetStack, rewardsStack[i]),
                assetAndRewardsStack[i].lastRewardPerTokenGlobal
            );
        }

        assertEq(wrappedAM.assetToTotalWrapped(assetStack), totalWrappedStack - positionAmountStack);
    }
}
