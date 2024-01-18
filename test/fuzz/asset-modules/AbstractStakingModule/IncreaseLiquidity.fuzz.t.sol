/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "StakingModule".
 */
contract IncreaseLiquidity_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint256 positionId) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address account,
        address randomAddress,
        uint128 amount,
        uint256 positionId,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : Amount is greater than zero
        vm.assume(amount > 0);
        // Given : positionId is greater than 0
        vm.assume(positionId > 0);
        // Given : Owner of positionId is not the Account
        stakingModule.setOwnerOfPositionId(randomAddress, positionId);
        // Given : A staking token and reward token pair are added to the stakingModule
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(assets, account, amounts);
        approveERC20TokensFor(assets, address(stakingModule), amounts, account);

        // When : Calling Stake
        // Then : The function should revert as the Account is not the owner of the positionId.
        vm.startPrank(account);
        vm.expectRevert(StakingModule.NotOwner.selector);
        stakingModule.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseLiquidity_PositionState(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);
        // Given : positionId is not 0
        vm.assume(positionId > 0);

        // Given : A staking token and reward token pair are added to the stakingModule
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(assets, account, amounts);
        approveERC20TokensFor(assets, address(stakingModule), amounts, account);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : Owner of positionId is Account
        stakingModule.setOwnerOfPositionId(account, positionId);

        // Given : TotalStaked is greater than 0 and updated totalStake should not be greater than uint128.
        (,, uint128 totalStaked) = stakingModule.assetState(asset);
        vm.assume(totalStaked > 0);
        vm.assume(totalStaked < type(uint128).max - amount);

        // Given : amount staked in position is > 0 (as we are staking in an existing position).
        vm.assume(positionState.amountStaked > 0);

        // When :  A user is staking via the Staking Module
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityIncreased(account, positionId, asset, amount);
        stakingModule.increaseLiquidity(positionId, amount);

        // Cache value to avoid stack too deep
        StakingModuleStateForAsset memory assetStateStack = assetState;
        uint256 amountStack = amount;
        uint256 amountStakedStack = positionState.amountStaked;
        uint256 lastRewardPositionStack = positionState.lastRewardPosition;
        uint256 lastRewardPerTokenPositionStack = positionState.lastRewardPerTokenPosition;

        // Then : Assets should have been transferred to the Staking Module
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amountStack);

        // And : Position values should be updated correctly
        StakingModule.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(positionId);

        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, amountStakedStack + amountStack);

        uint256 deltaReward = assetStateStack.currentRewardGlobal - assetStateStack.lastRewardGlobal;
        uint256 currentRewardPerToken =
            assetStateStack.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetStateStack.totalStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);

        uint256 deltaRewardPerToken = currentRewardPerToken - lastRewardPerTokenPositionStack;
        uint256 accruedRewards = amountStakedStack.mulDivDown(deltaRewardPerToken, 1e18);

        assertEq(newPositionState.lastRewardPosition, lastRewardPositionStack + accruedRewards);
    }

    function testFuzz_Success_increaseLiquidity_AssetState(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint256 positionId,
        uint128 amount,
        address account
    ) public notTestContracts(account) {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);
        // Given : positionId is not 0
        vm.assume(positionId > 0);

        // Given : A staking token and reward token pair are added to the stakingModule
        (address[] memory assets,) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        mintERC20TokensTo(assets, account, amounts);
        approveERC20TokensFor(assets, address(stakingModule), amounts, account);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : Owner of positionId is Account
        stakingModule.setOwnerOfPositionId(account, positionId);

        // Given : TotalStaked is greater than 0 and updated totalStake should not be greater than uint128.
        (,, uint128 totalStaked) = stakingModule.assetState(asset);
        vm.assume(totalStaked > 0);
        vm.assume(totalStaked < type(uint128).max - amount);

        // Given : amount staked in position is > 0 (as we are staking in an existing position).
        vm.assume(positionState.amountStaked > 0);

        // When :  A user is staking via the Staking Module
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityIncreased(account, positionId, asset, amount);
        stakingModule.increaseLiquidity(positionId, amount);

        // Cache value to avoid stack too deep
        StakingModuleStateForAsset memory assetStateStack = assetState;
        uint256 amountStack = amount;

        // Then : Assets should have been transferred to the Staking Module
        assertEq(ERC20Mock(asset).balanceOf(address(stakingModule)), amountStack);

        // And : Asset values should be updated correctly
        StakingModule.AssetState memory newAssetState;

        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);

        uint256 deltaReward = assetStateStack.currentRewardGlobal - assetStateStack.lastRewardGlobal;
        uint256 currentRewardPerToken =
            assetStateStack.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetStateStack.totalStaked);

        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, assetStateStack.currentRewardGlobal);
        assertEq(newAssetState.totalStaked, assetStateStack.totalStaked + amountStack);
    }
}
