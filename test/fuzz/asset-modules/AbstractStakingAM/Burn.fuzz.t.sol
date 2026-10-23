/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
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

    function testFuzz_Revert_burn_ZeroAmount(uint256 positionId) public {
        // When : Burning a position with nothing staked.
        // Then : It reverts.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakingAM.burn(positionId);
    }

    function testFuzz_Revert_burn_NotOwner(
        uint256 positionId,
        uint128 amountStaked,
        address owner,
        address randomAddress
    ) public {
        // Given : The position has a non-zero amount staked.
        amountStaked = uint128(bound(amountStaked, 1, type(uint128).max));
        stakingAM.setAmountStakedForPosition(positionId, amountStaked);

        // And : randomAddress is not the owner of the position.
        vm.assume(owner != randomAddress);
        stakingAM.setOwnerOfPositionId(owner, positionId);

        // When : randomAddress burns the position.
        // Then : It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakingAM.burn(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_burn_NonZeroReward(
        uint8 assetDecimals,
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));

        address asset;
        uint256 currentRewardAccount;
        {
            // Given : Add an Asset + reward token pair
            asset = addAsset(assetDecimals);
            vm.assume(account_ != asset);

            // Given: Valid state
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max);

            // And: State is persisted.
            setStakingAMState(assetState, positionState, surplusState, asset, positionId);

            // Given : Position is minted to the Account
            stakingAM.mintIdTo(account_, positionId);

            // Given : transfer Asset and rewardToken to stakingAM, as _withdrawAndClaim and _claimReward are not implemented on external staking contract
            // And reward is non-zero.
            deal(asset, address(stakingAM), positionState.amountStaked, true);
            currentRewardAccount = stakingAM.rewardOf(positionId);
            vm.assume(currentRewardAccount > 0);
            deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + currentRewardAccount, true);
        }

        // When : Account withdraws from stakingAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(rewardToken), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, positionState.amountStaked);
        stakingAM.burn(positionId);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(asset).balanceOf(account_), positionState.amountStaked);
        assertEq(rewardToken.balanceOf(account_), currentRewardAccount);

        // And : positionId should be burned.
        assertEq(stakingAM.balanceOf(account_), 0);

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
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerTokenGlobal(assetState));
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_burn_ZeroReward(
        uint8 assetDecimals,
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));

        address asset;
        {
            // Given : Add an Asset + reward token pair
            asset = addAsset(assetDecimals);
            vm.assume(account_ != asset);

            // Given: Valid state
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max);

            // And: reward is zero.
            positionState.lastRewardPosition = 0;
            positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
            assetState.currentRewardGlobal = 0;

            // And: State is persisted.
            setStakingAMState(assetState, positionState, surplusState, asset, positionId);

            // Given : Position is minted to the Account
            stakingAM.mintIdTo(account_, positionId);

            // Given : transfer Asset and rewardToken to stakingAM, as _withdrawAndClaim and _claimReward are not implemented on external staking contract
            deal(asset, address(stakingAM), positionState.amountStaked, true);
        }

        // When : Account withdraws from stakingAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, positionState.amountStaked);
        stakingAM.burn(positionId);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(asset).balanceOf(account_), positionState.amountStaked);
        assertEq(rewardToken.balanceOf(account_), 0);

        // And : positionId should be burned.
        assertEq(stakingAM.balanceOf(account_), 0);

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
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }
}
