/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM_Fuzz_Test, StakingAM } from "./_StakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "ClaimReward" function (position rewards) of contract "StakedAerodromeAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ClaimReward_Position_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimReward_Position_NotOwner(address owner, address randomAddress, uint96 positionId)
        public
    {
        // Given: The position is owned by another address than the caller.
        vm.assume(owner != randomAddress);
        stakedAerodromeAM.setOwnerOfPositionId(owner, positionId);
        vm.startPrank(randomAddress);

        // When: randomAddress claims the reward of the position.
        // Then: It reverts.
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedAerodromeAM.claimReward(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_claimReward_Position_NonZeroReward(
        address account_,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public {
        // Given: The position is owned by account_.
        vm.assume(account_ != address(0));
        stakedAerodromeAM.setOwnerOfPositionId(account_, positionId);

        // And: The aeroPool is allowed in the Registry, with its aeroGauge onboarded on the Asset Module.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: A valid asset and position state is persisted.
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max);
        setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

        // And: The reward of the position is non-zero, and the Asset Module holds it.
        uint256 currentRewardPosition = stakedAerodromeAM.rewardOf(positionId);

        // And: reward is non-zero.
        vm.assume(currentRewardPosition > 0);
        deal(AERO, address(stakedAerodromeAM), surplusState.lastRewardBalance + currentRewardPosition);

        // When: account_ claims the reward of the position.
        // Then: The reward is paid out.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(stakedAerodromeAM.REWARD_TOKEN()), uint128(currentRewardPosition));
        uint256 rewards = stakedAerodromeAM.claimReward(positionId);
        vm.stopPrank();

        // And: The claimed reward is returned.
        assertEq(rewards, currentRewardPosition);

        // And: The position state is updated.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        uint128 currentRewardPerToken = currentRewardPerTokenGlobal(assetState);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: The asset state is updated.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_claimReward_Position_ZeroReward(
        address account_,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public {
        // Given: The position is owned by account_.
        vm.assume(account_ != address(0));
        stakedAerodromeAM.setOwnerOfPositionId(account_, positionId);

        // And: The aeroPool is allowed in the Registry, with its aeroGauge onboarded on the Asset Module.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: A valid asset and position state, of which the reward for the position is zero.
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max);
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = 0;

        // And: The state is persisted.
        setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

        // When: account_ claims the reward of the position.
        vm.startPrank(account_);
        uint256 rewards = stakedAerodromeAM.claimReward(positionId);
        vm.stopPrank();

        // Then: No claimed rewards are returned.
        assertEq(rewards, 0);

        // And: account_ did not receive reward tokens.
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(account_), 0);

        // And: The position state is updated.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: The asset state is updated.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }
}
