/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import {
    StakedAerodromeAM_Fuzz_Test,
    StakedAerodromeAM_Fuzz_Test,
    StakingAM,
    ERC20Mock
} from "./_StakedAerodromeAM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "StakedAerodromeAM".
 */
contract IncreaseLiquidity_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint96 positionId) public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedAerodromeAM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address account_,
        address randomAddress,
        uint128 amount,
        uint96 positionId
    ) public canReceiveERC721(account_) {
        vm.assume(account_ != randomAddress);
        vm.assume(account_ != address(0));
        // Given : Amount is greater than zero
        vm.assume(amount > 0);
        // Given : positionId is greater than 0
        vm.assume(positionId > 0);
        // Given : Owner of positionId is not the Account
        stakedAerodromeAM.setOwnerOfPositionId(randomAddress, positionId);

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));
        vm.assume(account_ != address(aeroPool));
        vm.assume(account_ != aeroPool.poolFees());

        // And : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        vm.assume(account_ != address(aeroGauge));
        vm.assume(account_ != address(voter));

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        deal(address(aeroPool), account_, amount);
        vm.prank(account_);
        aeroPool.approve(address(stakedAerodromeAM), amount);

        // When : Calling Stake
        // Then : The function should revert as the Account is not the owner of the positionId.
        vm.startPrank(account_);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedAerodromeAM.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseLiquidity(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        vm.assume(account_ != address(0));
        {
            // Given : the aeroPool is allowed in the Registry
            aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
            vm.prank(users.owner);
            aerodromePoolAM.addAsset(address(aeroPool));
            vm.assume(account_ != address(aeroPool));
            vm.assume(account_ != aeroPool.poolFees());

            // And : Valid aeroGauge
            aeroGauge = createGaugeAerodrome(aeroPool, AERO);
            vm.assume(account_ != address(aeroGauge));
            vm.assume(account_ != address(voter));

            // And : Add asset and aeroGauge to the AM
            stakedAerodromeAM.addAsset(address(aeroGauge));

            // Given : Valid state
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, address(aeroPool), positionId);

            // Given : Owner of positionId is Account
            stakedAerodromeAM.setOwnerOfPositionId(account_, positionId);

            // And: updated totalStake should not be greater than uint128.
            // And: Amount staked is greater than zero.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            deal(address(aeroPool), account_, amount);
            vm.prank(account_);
            aeroPool.approve(address(stakedAerodromeAM), amount);
        }

        // When :  A user is increasing liquidity via the stakedAerodromeAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(positionId, address(aeroPool), amount);
        stakedAerodromeAM.increaseLiquidity(positionId, amount);

        // Then : Assets should have been staked in the aeroGauge
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), amount);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked + amount);
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken = assetState.lastRewardPerTokenGlobal
                + uint128(assetState.currentRewardGlobal.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        uint128 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = currentRewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        uint256 deltaReward = uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);
        assertEq(newPositionState.lastRewardPosition, positionState.lastRewardPosition + deltaReward);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), assetState.currentRewardGlobal);
    }
}
