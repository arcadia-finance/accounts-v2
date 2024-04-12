/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import {
    StakedAerodromeAM_Fuzz_Test,
    AbstractStakingAM_Fuzz_Test,
    StakingAM,
    ERC20Mock
} from "./_StakedAerodromeAM.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the "ClaimReward" function (position rewards) of contract "StakedAerodromeAM".
 */
contract ClaimReward_Position_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
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
        // Given: randomAddress is not the owner.
        vm.assume(owner != randomAddress);

        // Given : Owner of positionId is not randomAddress
        stakedAerodromeAM.setOwnerOfPositionId(owner, positionId);

        // When : randomAddress calls claimReward for positionId
        // Then : It should revert as randomAddress is not owner of the positionId
        vm.startPrank(randomAddress);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedAerodromeAM.claimReward(positionId);
        vm.stopPrank();
    }

    function testFuzz_Success_claimReward_Position_NonZeroReward(
        address account,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : owner of ERC721 positionId is Account
        stakedAerodromeAM.setOwnerOfPositionId(account, positionId);

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given: Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // And : stakedAerodromeAM should have sufficient amount of reward tokens
        uint256 currentRewardPosition = stakedAerodromeAM.rewardOf(positionId);

        // And reward is non-zero.
        vm.assume(currentRewardPosition > 0);

        deal(AERO, address(stakedAerodromeAM), currentRewardPosition);

        // When : Account calls claimReward()
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(stakedAerodromeAM.REWARD_TOKEN()), uint128(currentRewardPosition));
        uint256 rewards = stakedAerodromeAM.claimReward(positionId);
        vm.stopPrank();

        // Then : claimed rewards are returned.
        assertEq(rewards, currentRewardPosition);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken = assetState.lastRewardPerTokenGlobal
                + uint128(assetState.currentRewardGlobal.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_claimReward_Position_ZeroReward(
        address account,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState
    ) public {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : owner of ERC721 positionId is Account
        stakedAerodromeAM.setOwnerOfPositionId(account, positionId);

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given: Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // When : Account calls claimReward()
        vm.startPrank(account);
        uint256 rewards = stakedAerodromeAM.claimReward(positionId);
        vm.stopPrank();

        // Then : No claimed rewards are returned.
        assertEq(rewards, 0);

        // And : Account should have not received reward tokens.
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(account), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }
}
