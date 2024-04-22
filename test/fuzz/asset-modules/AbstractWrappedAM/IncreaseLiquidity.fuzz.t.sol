/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, ERC20Mock, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "../../../../lib/solmate/src/utils/SafeCastLib.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "WrappedAM".
 */
contract IncreaseLiquidity_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
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

    // TODO : add fuzzed positionState nad positionStatePerReward

    function testFuzz_Revert_increaseLiquidity_zeroAmount(uint96 positionId) public {
        // The increaseLiquidity function should revert when trying to stake 0 amount.
        vm.expectRevert(WrappedAM.ZeroAmount.selector);
        wrappedAM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        uint128 amount,
        address account,
        address randomAddress,
        uint96 positionId
    ) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);

        // Given : Owner of positionId is not the Account
        wrappedAM.setOwnerOfPositionId(randomAddress, positionId);

        // When : Calling increaseLiquidity()
        // Then : The function should revert as the Account is not the owner of the positionId
        vm.startPrank(account);
        vm.expectRevert(WrappedAM.NotOwner.selector);
        wrappedAM.increaseLiquidity(positionId, amount);
    }

    function testFuzz_Success_increaseLiquidity(
        address account,
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address underlyingAsset,
        address[2] calldata rewards,
        uint128 amount,
        uint128 totalWrapped
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(wrappedAM));

        address asset = address(mockERC20.token1);

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

        // Stack too deep
        address accountStack = account;
        address[] memory rewards_ = Utils.castArrayStaticToDynamic(rewards);
        address underlyingAssetStack = underlyingAsset;
        address assetStack = asset;
        uint128 amountStack = amount;

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            assetStack,
            rewards_,
            1,
            totalWrapped_,
            underlyingAssetStack
        );

        // Stack too deep
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardsStack =
            assetAndRewardState_;
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[] memory positionStatePerRewardStack =
            positionStatePerReward_;
        uint128 totalWrappedStack = totalWrapped_;
        uint128 positionAmountStack = positionState_.amountWrapped;

        // And: updated totalWrapped should not be greater than uint128.
        // And: Amount wrapped is greater than zero.
        vm.assume(totalWrapped_ < type(uint128).max);
        amountStack = uint128(bound(amountStack, 1, type(uint128).max - totalWrapped_));

        // And : Get and approve assets to deposit
        mintERC20TokenTo(assetStack, accountStack, amountStack);
        approveERC20TokenFor(assetStack, address(wrappedAM), amountStack, accountStack);

        // And : Owner of positionId is Account
        wrappedAM.setOwnerOfPositionId(accountStack, 1);

        // When:  A user is increasing it's position via the wrappedAM
        vm.startPrank(accountStack);
        vm.expectEmit();
        emit WrappedAM.LiquidityIncreased(1, assetStack, amountStack);
        wrappedAM.increaseLiquidity(1, amountStack);

        // Then: Assets should have been transferred to the Wrapped Asset Module.
        assertEq(ERC20Mock(assetStack).balanceOf(address(wrappedAM)), amountStack);

        // And: Position state per reward and lastRewardPerTokenGlobal should be updated correctly.
        for (uint256 i; i < rewards_.length; ++i) {
            uint128 lastRewardPerTokenGlobal = wrappedAM.lastRewardPerTokenGlobal(assetStack, rewards_[i]);
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(1, rewards_[i]);

            uint128 currentRewardPerToken;
            unchecked {
                currentRewardPerToken = assetAndRewardsStack[i].lastRewardPerTokenGlobal
                    + SafeCastLib.safeCastTo128(
                        assetAndRewardsStack[i].currentRewardGlobal.mulDivDown(1e18, totalWrappedStack)
                    );
            }
            uint128 deltaRewardPerToken;
            unchecked {
                deltaRewardPerToken = currentRewardPerToken - positionStatePerRewardStack[i].lastRewardPerTokenPosition;
            }
            uint256 deltaReward = uint256(positionAmountStack).mulDivDown(deltaRewardPerToken, 1e18);

            assertEq(lastRewardPosition, positionStatePerRewardStack[i].lastRewardPosition + deltaReward);
            assertEq(lastRewardPerTokenPosition, currentRewardPerToken);
            assertEq(lastRewardPerTokenGlobal, assetAndRewardsStack[i].lastRewardPerTokenGlobal);
            assertEq(wrappedAM.assetToTotalWrapped(assetStack), amountStack + totalWrappedStack);
        }

        (address customAsset, uint128 amountWrapped) = wrappedAM.positionState(1);
        assertEq(customAsset, getCustomAsset(assetStack, rewards_));
        assertEq(amountWrapped, positionAmountStack + amountStack);
    }
}
