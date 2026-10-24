/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM, ERC20Mock } from "./_StakedMetadex03AM.fuzz.t.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract DecreaseLiquidity_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_decreaseLiquidity_ZeroAmount(uint256 id) public {
        // Given: Amount is 0.
        uint128 amount = 0;

        // When: Trying to withdraw zero amount.
        // Then: It should revert.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedMetadex03AM.decreaseLiquidity(id, amount);
    }

    function testFuzz_Revert_decreaseLiquidity_NotOwner(uint256 id, uint128 amount, address owner) public {
        // Given: Amount is greater than 0.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And: Owner is not the caller.
        vm.assume(owner != users.accountOwner);

        // And: Set owner of the specific positionId.
        stakedMetadex03AM.setOwnerOfPositionId(owner, id);

        // When: Trying to withdraw a position not owned by the caller.
        // Then: It should revert.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedMetadex03AM.decreaseLiquidity(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state, of which the staked amount is smaller as type(uint128).max.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        vm.assume(positionState.amountStaked < type(uint128).max);

        // And: State is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: Amount withdrawn is bigger than the balance.
        amount = uint128(bound(amount, positionState.amountStaked + 1, type(uint128).max));

        // When: Calling decreaseLiquidity().
        // Then: It should revert as remaining balance is too low.
        vm.startPrank(account_);
        vm.expectRevert(stdError.arithmeticError);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_PartialWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state, of which the staked amount is bigger as 1 and the reward is zero.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        vm.assume(positionState.amountStaked > 1);
        positionState.lastRewardPosition = 0;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: Amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When: Account withdraws from stakingAM.
        // Then: The liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(metadex03Pool), amount);
        uint256 rewards = stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // And: Account should get the withdrawn amount and no reward tokens.
        assertEq(metadex03Pool.balanceOf(account_), amount);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), 0);

        // And: The amount is withdrawn from the staker of the position.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), positionState.amountStaked - amount);

        // And: No claimed rewards are returned.
        assertEq(rewards, 0);

        // And: The positionId should not be burned.
        assertEq(stakedMetadex03AM.balanceOf(account_), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, positionState.lastRewardPerTokenPosition);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset values should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_PartialWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state, of which the staked amount is bigger as 1.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        vm.assume(positionState.amountStaked > 1);

        // And: State is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: The credited reward plus what the staker of the position earned is non-zero.
        uint256 reward = uint256(positionState.lastRewardPosition) + assetState.currentRewardGlobal;
        vm.assume(reward > 0);

        // And: Amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When: Account withdraws from stakingAM.
        // Then: The reward is paid out and the liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, receiptToken, uint128(reward));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(metadex03Pool), amount);
        uint256 rewards = stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // And: Account should get the withdrawn amount and reward tokens.
        assertEq(metadex03Pool.balanceOf(account_), amount);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), reward);

        // And: Claimed rewards are returned.
        assertEq(rewards, reward);

        // And: The amount is withdrawn from the staker of the position.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), positionState.amountStaked - amount);

        // And: The positionId should not be burned.
        assertEq(stakedMetadex03AM.balanceOf(account_), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, positionState.lastRewardPerTokenPosition);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset values should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_FullWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state, of which the reward is zero.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionState.lastRewardPosition = 0;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // When: Account withdraws full position from stakingAM.
        // Then: The liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(metadex03Pool), positionState.amountStaked);
        uint256 rewards = stakedMetadex03AM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // And: Account should get the staking tokens and no reward tokens.
        assertEq(metadex03Pool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), 0);

        // And: The staker of the position holds no stake and no penalty window anymore.
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertEq(metadex03Gauge.balanceOf(staker), 0);
        assertEq(metadex03Gauge.depositBlock(staker), 0);

        // And: No claimed rewards are returned.
        assertEq(rewards, 0);

        // And: The positionId should be burned.
        assertEq(stakedMetadex03AM.balanceOf(account_), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_FullWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);

        // And: State is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: The credited reward plus what the staker of the position earned is non-zero.
        uint256 reward = uint256(positionState.lastRewardPosition) + assetState.currentRewardGlobal;
        vm.assume(reward > 0);

        // When: Account withdraws full position from stakingAM.
        // Then: The reward is paid out and the liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit(true, true, true, true, address(stakedMetadex03AM));
        emit StakingAM.RewardPaid(positionId, receiptToken, uint128(reward));
        vm.expectEmit(true, true, true, true, address(stakedMetadex03AM));
        emit StakingAM.LiquidityDecreased(positionId, address(metadex03Pool), positionState.amountStaked);
        uint256 rewards = stakedMetadex03AM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // And: Account should get the staking and reward tokens.
        assertEq(metadex03Pool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), reward);

        // And: Claimed rewards are returned.
        assertEq(rewards, reward);

        // And: The positionId should be burned.
        assertEq(stakedMetadex03AM.balanceOf(account_), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_FullWithdraw_RewardsAccounting(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state, of which the totalStaked exceeds the stake of the position.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        vm.assume(assetState.totalStaked > positionState.amountStaked);

        // And: State is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: The credited reward plus what the staker of the position earned is non-zero.
        uint256 reward = uint256(positionState.lastRewardPosition) + assetState.currentRewardGlobal;
        vm.assume(reward > 0);

        // When: Account withdraws full position from stakingAM.
        vm.prank(account_);
        uint256 rewards = stakedMetadex03AM.decreaseLiquidity(positionId, positionState.amountStaked);

        // Then: The credited reward plus all its staker earned is paid.
        assertEq(rewards, reward);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), reward);

        // And: No rounding remainder stays behind in the Asset Module.
        assertEq(ERC20Mock(receiptToken).balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);
        assertEq(stakedMetadex03AM.claimableSurplus(), surplusState.bookedSurplus);

        // And: The accumulators of the asset are untouched.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_MintReverts_SoleStaker(uint128 amount, uint256 emissions) public {
        // Given: A sole position with emissions above the gauge's flooring per 1e18 of stake.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertGt(metadex03Gauge.earned(staker), 0);

        // And: The chain is active, but the mint reverts.
        vm.mockCallRevert(address(leafVoter), abi.encodeWithSignature("mintEmissions(address[],uint128[])"), "");

        // When: Calling decreaseLiquidity().
        // Then: It does not revert, only what the gauge delivered is distributed.
        vm.prank(users.accountOwner);
        uint256 rewards = stakedMetadex03AM.decreaseLiquidity(positionId, amount);

        // And: The position leaves with its Asset and no reward.
        assertEq(rewards, 0);
        assertEq(metadex03Pool.balanceOf(users.accountOwner), amount);
        assertGt(metadex03Gauge.deferredEmissions(staker), 0);
    }

    function testFuzz_Success_decreaseLiquidity_ChainSuspended_NonZeroEarned(uint128 amount, uint256 emissions) public {
        // Given: A position with emissions above the gauge's flooring per 1e18 of stake.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        address staker = stakedMetadex03AM.getStaker(positionId);
        uint256 earned = metadex03Gauge.earned(staker);
        assertGt(earned, 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // When: Calling decreaseLiquidity().
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);

        // Then: The withdrawal succeeds and the gauge defers the staker's emissions.
        assertEq(metadex03Pool.balanceOf(users.accountOwner), amount);
        assertEq(metadex03Gauge.deferredEmissions(staker), earned);
    }

    function testFuzz_Success_decreaseLiquidity_ChainResumed(uint128 amount, uint256 emissions) public {
        // Given: A position with emissions above the gauge's flooring per 1e18 of stake.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertGt(metadex03Gauge.earned(staker), 0);

        // And: The chain was suspended, so a claim reverted while the emissions stayed earned.
        setChainSuspended(true);
        vm.prank(users.accountOwner);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03AM.claimReward(positionId);

        // And: The chain is resumed.
        setChainSuspended(false);
        uint256 earned = metadex03Gauge.earned(staker);

        // When: Calling decreaseLiquidity().
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);

        // Then: The user received the staked LP and the earned emissions of the staker.
        assertEq(metadex03Pool.balanceOf(users.accountOwner), amount);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(users.accountOwner), earned);
    }

    function testFuzz_Success_decreaseLiquidity_DonationNotCredited(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint256 emissions,
        uint256 donation
    ) public {
        // Given: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position with emissions above the gauge's flooring per 1e18 of stake.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // And: Reward tokens reached the Asset Module outside an interaction, which the recipient claims.
        donation = bound(donation, 1, type(uint128).max);
        deal(receiptToken, address(stakedMetadex03AM), surplusState.lastRewardBalance + donation);
        uint256 claimable = surplusState.bookedSurplus + donation;
        assertEq(stakedMetadex03AM.claimableSurplus(), claimable);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20Mock(receiptToken).balanceOf(surplusRecipient), claimable);

        // When: The owner withdraws its full position.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);

        // Then: The owner is paid the earned emissions of its staker alone.
        assertEq(ERC20Mock(receiptToken).balanceOf(users.accountOwner), earned);

        // And: Nothing stays behind, nothing extra is booked.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(
            ERC20Mock(receiptToken).balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance - surplusState.bookedSurplus
        );

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }
}
