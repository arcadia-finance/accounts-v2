/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, StakingAM } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claimReward" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ClaimReward_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
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
        address account_,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));

        // Given : owner of ERC721 positionId is Account
        stakingAM.setOwnerOfPositionId(account_, positionId);

        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given: Valid state
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // Given : The claim function on the external staking contract is not implemented, thus we fund the stakingAM with reward tokens that should be transferred.
        uint256 currentRewardPosition = stakingAM.rewardOf(positionId);

        // And: reward is non-zero.
        vm.assume(currentRewardPosition > 0);
        deal(
            address(stakingAM.REWARD_TOKEN()),
            address(stakingAM),
            surplusState.lastRewardBalance + currentRewardPosition,
            true
        );

        // When : Account calls claimReward()
        vm.startPrank(account_);
        vm.expectEmit();
        // forge-lint: disable-next-item(unsafe-typecast)
        emit StakingAM.RewardPaid(positionId, address(stakingAM.REWARD_TOKEN()), uint128(currentRewardPosition));
        uint256 rewards = stakingAM.claimReward(positionId);
        vm.stopPrank();

        // Then : claimed rewards are returned.
        assertEq(rewards, currentRewardPosition);

        // And : Account should have received the reward tokens.
        assertEq(currentRewardPosition, stakingAM.REWARD_TOKEN().balanceOf(account_));

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
        uint128 currentRewardPerToken = currentRewardPerTokenGlobal(assetState);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_claimReward_ZeroReward(
        address account_,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));

        // Given : owner of ERC721 positionId is Account
        stakingAM.setOwnerOfPositionId(account_, positionId);

        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given: Valid state
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max);

        // And: reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // When : Account calls claimReward()
        vm.startPrank(account_);
        uint256 rewards = stakingAM.claimReward(positionId);
        vm.stopPrank();

        // Then : No claimed rewards are returned.
        assertEq(rewards, 0);

        // And : Account should have not received reward tokens.
        assertEq(stakingAM.REWARD_TOKEN().balanceOf(account_), 0);

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
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_claimReward_BookedSurplusNotCredited(
        uint8 assetDecimals,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 reward,
        uint128 booked
    ) public {
        // Given: An Asset is added to the stakingAM.
        address asset = addAsset(assetDecimals);

        // And: Valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: The staking contract will deliver a reward, of which the hook books a part for the recipient.
        reward = uint128(bound(reward, 1, type(uint128).max));
        booked = uint128(bound(booked, 1, reward));
        stakingAM.setActualRewardBalance(asset, reward);
        stakingAM.setBookedAmount(booked);
        uint256 expectedReward = _credited(amount, reward - booked);

        // When: The position claims.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakingAM.claimReward(positionId);

        // Then: The owner is paid the delivered reward less the booked part.
        assertEq(rewards, expectedReward);
        assertEq(rewardToken.balanceOf(users.liquidityProvider), expectedReward);

        // And: The booked amount is not credited to the position.
        assertEq(stakingAM.bookedSurplus(), surplusState.bookedSurplus + booked);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_claimReward_DonationNotCredited(
        uint8 assetDecimals,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 reward,
        uint128 donation
    ) public {
        // Given: An Asset is added to the stakingAM.
        address asset = addAsset(assetDecimals);

        // And: Valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: The staking contract will deliver a reward.
        reward = uint128(bound(reward, 1, type(uint128).max));
        stakingAM.setActualRewardBalance(asset, reward);

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + donation, true);
        uint256 expectedReward = _credited(amount, reward);

        // When: The position claims.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakingAM.claimReward(positionId);

        // Then: The owner is paid the delivered reward alone.
        assertEq(rewards, expectedReward);
        assertEq(rewardToken.balanceOf(users.liquidityProvider), expectedReward);

        // And: The donation is booked for the recipient, the accrual rounding stays for the positions.
        assertEq(stakingAM.bookedSurplus(), surplusState.bookedSurplus + donation);
        assertEq(stakingAM.claimableSurplus(), surplusState.bookedSurplus + donation);
        assertEq(
            rewardToken.balanceOf(address(stakingAM)),
            surplusState.lastRewardBalance + uint256(donation) + reward - expectedReward
        );
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }
}
