/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { StakedAerodromeAM_Fuzz_Test, StakingAM } from "./_StakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "StakedAerodromeAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
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
        // Given: Any positionId.

        // When: Calling increaseLiquidity() for a zero amount.
        // Then: It reverts.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedAerodromeAM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address account_,
        address randomAddress,
        uint128 amount,
        uint96 positionId
    ) public canReceiveERC721(account_) {
        // Given: A non-zero positionId, owned by another address than the Account.
        vm.assume(account_ != randomAddress);
        vm.assume(account_ != address(0));
        // Given: Amount is greater than zero.
        amount = uint128(bound(amount, 1, type(uint128).max));
        // And: positionId is greater than zero.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        // And: Owner of positionId is not the Account.
        stakedAerodromeAM.setOwnerOfPositionId(randomAddress, positionId);

        // And: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));
        vm.assume(account_ != address(aeroPool));
        vm.assume(account_ != aeroPool.poolFees());

        // And: Valid aeroGauge.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        vm.assume(account_ != address(aeroGauge));
        vm.assume(account_ != address(voter));

        // And: Add asset and aeroGauge to the AM.
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: The Account holds a non-zero LP balance, approved to the Asset Module.
        amount = uint128(bound(amount, 1, type(uint128).max));
        deal(address(aeroPool), account_, amount);
        vm.prank(account_);
        aeroPool.approve(address(stakedAerodromeAM), amount);

        // When: Calling increaseLiquidity() for that positionId.
        // Then: It reverts.
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
        address account_,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));
        {
            // And: The aeroPool is allowed in the Registry.
            aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
            vm.prank(users.owner);
            aerodromePoolAM.addAsset(address(aeroPool));
            vm.assume(account_ != address(aeroPool));
            vm.assume(account_ != aeroPool.poolFees());

            // And: Valid aeroGauge.
            aeroGauge = createGaugeAerodrome(aeroPool, AERO);
            vm.assume(account_ != address(aeroGauge));
            vm.assume(account_ != address(voter));

            // And: Add asset and aeroGauge to the AM.
            stakedAerodromeAM.addAsset(address(aeroGauge));

            // And: Valid state.
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max - 1);

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

            // And: Owner of positionId is Account.
            stakedAerodromeAM.setOwnerOfPositionId(account_, positionId);

            // And: Amount staked is non-zero and the updated totalStaked still fits a uint128.
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            // And: Account has a balance of aeroPool LP tokens, approved to the Asset Module.
            deal(address(aeroPool), account_, amount);
            vm.prank(account_);
            aeroPool.approve(address(stakedAerodromeAM), amount);
        }

        // When: A user is increasing liquidity via the stakedAerodromeAM.
        // Then: The liquidity is increased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(positionId, address(aeroPool), amount);
        stakedAerodromeAM.increaseLiquidity(positionId, amount);

        // And: Assets should have been staked in the aeroGauge.
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
        uint128 currentRewardPerToken = currentRewardPerTokenGlobal(assetState);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        uint128 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = currentRewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        uint256 deltaReward = uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);
        assertEq(newPositionState.lastRewardPosition, positionState.lastRewardPosition + deltaReward);

        // And: Asset values should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
        assertEq(
            stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)),
            surplusState.lastRewardBalance + assetState.currentRewardGlobal
        );
    }
}
