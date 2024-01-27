/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "StakingAM".
 */
contract Burn_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_burn_NonZeroReward(
        uint8 assetDecimals,
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));
        vm.assume(account != address(stakingAM));
        vm.assume(account != address(rewardToken));

        address asset;
        uint256 currentRewardAccount;
        {
            // Given : Add an Asset + reward token pair
            asset = addAsset(assetDecimals);
            vm.assume(account != asset);

            // Given: Valid state
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And : Account has a non-zero balance.
            vm.assume(positionState.amountStaked > 0);

            // And: State is persisted.
            setStakingAMState(assetState, positionState, asset, positionId);

            // Given : Position is minted to the Account
            stakingAM.mintIdTo(account, positionId);

            // Given : transfer Asset and rewardToken to stakingAM, as _withdraw and _claimReward are not implemented on external staking contract
            address[] memory tokens = new address[](2);
            tokens[0] = asset;
            tokens[1] = address(rewardToken);

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = positionState.amountStaked;
            currentRewardAccount = stakingAM.rewardOf(positionId);
            amounts[1] = currentRewardAccount;

            // And reward is non-zero.
            vm.assume(currentRewardAccount > 0);

            mintERC20TokensTo(tokens, address(stakingAM), amounts);
        }

        // When : Account withdraws from stakingAM
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(rewardToken), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, positionState.amountStaked);
        stakingAM.burn(positionId);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(asset).balanceOf(account), positionState.amountStaked);
        assertEq(rewardToken.balanceOf(account), currentRewardAccount);

        // And : positionId should be burned.
        assertEq(stakingAM.balanceOf(account), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingAM.assetState(asset);
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward * 1e18 / assetState.totalStaked);
        }
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_burn_ZeroReward(
        uint8 assetDecimals,
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));
        vm.assume(account != address(stakingAM));
        vm.assume(account != address(rewardToken));

        address asset;
        {
            // Given : Add an Asset + reward token pair
            asset = addAsset(assetDecimals);
            vm.assume(account != asset);

            // Given: Valid state
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And : Account has a non-zero balance.
            vm.assume(positionState.amountStaked > 0);

            // And reward is zero.
            positionState.lastRewardPosition = 0;
            positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
            assetState.currentRewardGlobal = assetState.lastRewardGlobal;

            // And: State is persisted.
            setStakingAMState(assetState, positionState, asset, positionId);

            // Given : Position is minted to the Account
            stakingAM.mintIdTo(account, positionId);

            // Given : transfer Asset and rewardToken to stakingAM, as _withdraw and _claimReward are not implemented on external staking contract
            address[] memory tokens = new address[](2);
            tokens[0] = asset;
            tokens[1] = address(rewardToken);

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = positionState.amountStaked;

            mintERC20TokensTo(tokens, address(stakingAM), amounts);
        }

        // When : Account withdraws from stakingAM
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, positionState.amountStaked);
        stakingAM.burn(positionId);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(asset).balanceOf(account), positionState.amountStaked);
        assertEq(rewardToken.balanceOf(account), 0);

        // And : positionId should be burned.
        assertEq(stakingAM.balanceOf(account), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (, newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }
}
