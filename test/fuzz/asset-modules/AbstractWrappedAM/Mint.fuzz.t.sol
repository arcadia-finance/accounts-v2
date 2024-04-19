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
 * @notice Fuzz tests for the function "mint" of contract "WrappedAM".
 */
contract Mint_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
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

    function testFuzz_Revert_mint_zeroAmount(address asset) public {
        // The mint function should revert when trying to stake 0 amount.
        vm.expectRevert(WrappedAM.ZeroAmount.selector);
        wrappedAM.mint(asset, 0);
    }

    function testFuzz_Revert_mint_AssetNotAllowed(
        uint128 amount,
        uint8 assetDecimals,
        address customAsset,
        address account
    ) public {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);

        // And : AssetDecimals is max 18
        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(new ERC20Mock("Asset", "AST", assetDecimals));

        mintERC20TokenTo(asset, account, amount);
        approveERC20TokenFor(asset, address(wrappedAM), amount, account);

        // And : customAsset struct is set
        address[] memory emptyArr;
        wrappedAM.setCustomAssetInfo(customAsset, asset, emptyArr);
        // And : Allowed should be set to false
        wrappedAM.setCustomAssetNotAllowed(customAsset);

        // When : Calling mint()
        // Then : The function should revert as the asset has not been added to the Staking Module.
        vm.startPrank(account);
        vm.expectRevert(WrappedAM.AssetNotAllowed.selector);
        wrappedAM.mint(asset, amount);
    }

    function testFuzz_Success_mint_MintAmountGreaterThan0(
        uint8 assetDecimals,
        address account,
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        address underlyingAsset,
        address[2] calldata rewards,
        uint128 amount,
        uint128 totalWrapped
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(wrappedAM));

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(mockERC20.token1);

        // Given : Valid state
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState;
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward;
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

        address[] memory rewards_ = Utils.castArrayStaticToDynamic(rewards);

        // Stack too deep
        address accountStack = account;
        address underlyingAssetStack = underlyingAsset;
        uint128 amountStack = amount;
        address assetStack = asset;

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            rewards_,
            0,
            totalWrapped_,
            underlyingAssetStack
        );

        // Stack too deep
        uint256[] memory currentRewardGlobalStack = new uint256[](2);
        currentRewardGlobalStack[0] = assetAndRewardState_[0].currentRewardGlobal;
        currentRewardGlobalStack[1] = assetAndRewardState_[1].currentRewardGlobal;
        uint128[] memory lastRewardPerTokenGlobalStack = new uint128[](2);
        lastRewardPerTokenGlobalStack[0] = assetAndRewardState_[0].lastRewardPerTokenGlobal;
        lastRewardPerTokenGlobalStack[1] = assetAndRewardState_[1].lastRewardPerTokenGlobal;
        uint128 totalWrappedStack = totalWrapped_;

        // And: updated totalWrapped should not be greater than uint128.
        // And: Amount wrapped is greater than zero.
        vm.assume(totalWrapped_ < type(uint128).max);
        amountStack = uint128(bound(amountStack, 1, type(uint128).max - totalWrapped_));

        // And : Get and approve assets to deposit
        mintERC20TokenTo(assetStack, accountStack, amountStack);
        approveERC20TokenFor(assetStack, address(wrappedAM), amountStack, accountStack);

        // When:  A user is deposition via the wrappedAM
        vm.startPrank(accountStack);
        vm.expectEmit();
        emit WrappedAM.LiquidityIncreased(1, assetStack, amountStack);
        uint256 positionId = wrappedAM.mint(getCustomAsset(assetStack, rewards_), amountStack);

        // Then: Assets should have been transferred to the Wrapped Asset Module.
        assertEq(ERC20Mock(assetStack).balanceOf(address(wrappedAM)), amountStack);

        // And: New position has been minted to Account.
        assertEq(wrappedAM.ownerOf(positionId), accountStack);

        // And: Position state per reward and lastRewardPerTokenGlobal should be updated correctly.
        for (uint256 i; i < rewards_.length; ++i) {
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(positionId, rewards_[i]);

            uint128 lastRewardPerTokenGlobal = wrappedAM.lastRewardPerTokenGlobal(assetStack, rewards_[i]);

            uint128 currentRewardPerToken;
            unchecked {
                currentRewardPerToken = lastRewardPerTokenGlobalStack[i]
                    + SafeCastLib.safeCastTo128(currentRewardGlobalStack[i].mulDivDown(1e18, totalWrappedStack));
            }

            assertEq(lastRewardPosition, 0);
            assertEq(lastRewardPerTokenPosition, currentRewardPerToken);
            assertEq(lastRewardPerTokenGlobal, lastRewardPerTokenGlobalStack[i]);
            assertEq(wrappedAM.assetToTotalWrapped(assetStack), amountStack + totalWrappedStack);
        }

        (address customAsset, uint128 amountWrapped) = wrappedAM.positionState(positionId);
        assertEq(customAsset, getCustomAsset(assetStack, rewards_));
        assertEq(amountWrapped, amountStack);
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        uint8 assetDecimals,
        address account,
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        address underlyingAsset,
        address[2] calldata rewards,
        uint128 amount,
        uint128 totalWrapped
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));
        vm.assume(account != address(wrappedAM));

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(mockERC20.token1);

        // Given : Valid state
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState;
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward;
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

        address[] memory rewards_ = Utils.castArrayStaticToDynamic(rewards);

        // And : totalWrapped is 0
        totalWrapped_ = 0;

        // Stack too deep
        address accountStack = account;
        address underlyingAssetStack = underlyingAsset;
        uint128 amountStack = amount;
        address assetStack = asset;

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            rewards_,
            0,
            totalWrapped_,
            underlyingAssetStack
        );

        // Stack too deep
        uint256[] memory currentRewardGlobalStack = new uint256[](2);
        currentRewardGlobalStack[0] = assetAndRewardState_[0].currentRewardGlobal;
        currentRewardGlobalStack[1] = assetAndRewardState_[1].currentRewardGlobal;
        uint128[] memory lastRewardPerTokenGlobalStack = new uint128[](2);
        lastRewardPerTokenGlobalStack[0] = assetAndRewardState_[0].lastRewardPerTokenGlobal;
        lastRewardPerTokenGlobalStack[1] = assetAndRewardState_[1].lastRewardPerTokenGlobal;

        // And: Amount wrapped is greater than zero.
        amountStack = uint128(bound(amountStack, 1, type(uint128).max - totalWrapped_));

        // And : Get and approve assets to deposit
        mintERC20TokenTo(assetStack, accountStack, amountStack);
        approveERC20TokenFor(assetStack, address(wrappedAM), amountStack, accountStack);

        // When:  A user is deposition via the wrappedAM
        vm.startPrank(accountStack);
        vm.expectEmit();
        emit WrappedAM.LiquidityIncreased(1, assetStack, amountStack);
        uint256 positionId = wrappedAM.mint(getCustomAsset(assetStack, rewards_), amountStack);

        // Then: Assets should have been transferred to the Wrapped Asset Module.
        assertEq(ERC20Mock(assetStack).balanceOf(address(wrappedAM)), amountStack);

        // And: New position has been minted to Account.
        assertEq(wrappedAM.ownerOf(positionId), accountStack);

        // And: Position state per reward and lastRewardPerTokenGlobal should be updated correctly.
        for (uint256 i; i < rewards_.length; ++i) {
            (uint128 lastRewardPerTokenPosition, uint128 lastRewardPosition) =
                wrappedAM.rewardStatePosition(positionId, rewards_[i]);

            uint128 lastRewardPerTokenGlobal = wrappedAM.lastRewardPerTokenGlobal(assetStack, rewards_[i]);

            assertEq(lastRewardPosition, 0);
            assertEq(lastRewardPerTokenPosition, lastRewardPerTokenGlobalStack[i]);
            assertEq(lastRewardPerTokenGlobal, lastRewardPerTokenGlobalStack[i]);
            assertEq(wrappedAM.assetToTotalWrapped(assetStack), amountStack);
        }

        (address customAsset, uint128 amountWrapped) = wrappedAM.positionState(positionId);
        assertEq(customAsset, getCustomAsset(assetStack, rewards_));
        assertEq(amountWrapped, amountStack);
    }
}
