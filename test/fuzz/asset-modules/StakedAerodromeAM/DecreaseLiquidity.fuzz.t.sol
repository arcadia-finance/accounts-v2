/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedAerodromeAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_StakedAerodromeAM.fuzz.t.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "StakedAerodromeAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract DecreaseLiquidity_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedAerodromeAM_Fuzz_Test.setUp();
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
        stakedAerodromeAM.decreaseLiquidity(id, amount);
    }

    function testFuzz_Revert_decreaseLiquidity_NotOwner(uint256 id, uint128 amount, address owner) public {
        // Given: Amount is greater than 0.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // And: Owner is not the caller.
        vm.assume(owner != users.accountOwner);

        // And: Set owner of the specific positionId.
        stakedAerodromeAM.setOwnerOfPositionId(owner, id);

        // When: Trying to withdraw a position not owned by the caller.
        // Then: It should revert.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedAerodromeAM.decreaseLiquidity(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint128 amount,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

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
            givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max - 1);

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

        // And: Position is minted to the Account.
        stakedAerodromeAM.mintIdTo(account_, positionId);

        // And: Amount withdrawn is bigger than the balance.
        amount = uint128(bound(amount, positionState.amountStaked + 1, type(uint128).max));

        // When: Calling decreaseLiquidity().
        // Then: It should revert as remaining balance is too low.
        vm.startPrank(account_);
        vm.expectRevert(stdError.arithmeticError);
        stakedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_PartialWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint128 amount,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

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

        {
            // And: Valid state.
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 2, type(uint128).max);

            // And: The reward is zero.
            positionState.lastRewardPosition = 0;
            positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
            assetState.currentRewardGlobal = 0;

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

            // And: Position is minted to the Account.
            stakedAerodromeAM.mintIdTo(account_, positionId);

            // And: The stakedAerodromeAM has a staked balance in aeroGauge.
            deal(address(aeroPool), address(stakedAerodromeAM), positionState.amountStaked);
            vm.startPrank(address(stakedAerodromeAM));
            aeroPool.approve(address(aeroGauge), positionState.amountStaked);
            aeroGauge.deposit(positionState.amountStaked);
            vm.stopPrank();
        }

        // And: Amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When: Account withdraws from stakingAM.
        // Then: The liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(aeroPool), amount);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // And: Account should get the withdrawed amount and reward tokens.
        assertEq(aeroPool.balanceOf(account_), amount);
        assertEq(ERC20Mock(AERO).balanceOf(account_), 0);

        // And: No claimed rewards are returned.
        assertEq(rewards, 0);

        // And: The positionId should not be burned.
        assertEq(stakedAerodromeAM.balanceOf(account_), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset values should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_PartialWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint128 amount,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

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

        uint256 currentRewardAccount;
        {
            // And: Valid state.
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 2, type(uint128).max);

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

            // And: Position is minted to the Account.
            stakedAerodromeAM.mintIdTo(account_, positionId);

            // And: The stakedAerodromeAM has a staked balance in aeroGauge.
            deal(address(aeroPool), address(stakedAerodromeAM), positionState.amountStaked);
            vm.startPrank(address(stakedAerodromeAM));
            aeroPool.approve(address(aeroGauge), positionState.amountStaked);
            aeroGauge.deposit(positionState.amountStaked);
            vm.stopPrank();

            // And: The reward of the position is non-zero, and the Asset Module holds it.
            currentRewardAccount = stakedAerodromeAM.rewardOf(positionId);
            vm.assume(currentRewardAccount > 0);
            deal(AERO, address(stakedAerodromeAM), surplusState.lastRewardBalance + currentRewardAccount);
        }

        // And: Amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When: Account withdraws from stakingAM.
        // Then: The reward is paid out and the liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, AERO, uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(aeroPool), amount);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // And: Account should get the withdrawed amount and reward tokens.
        assertEq(aeroPool.balanceOf(account_), amount);
        assertEq(ERC20Mock(AERO).balanceOf(account_), currentRewardAccount);

        // And: Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And: Rewards have been claimed from the aeroGauge.
        assertEq(ERC20Mock(AERO).balanceOf(address(aeroGauge)), 0);

        // And: The positionId should not be burned.
        assertEq(stakedAerodromeAM.balanceOf(account_), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(aeroPool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        uint128 currentRewardPerToken = currentRewardPerTokenGlobal(assetState);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset values should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
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
            givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max);

        // And: The reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

        // And: Position is minted to the Account.
        stakedAerodromeAM.mintIdTo(account_, positionId);

        // And: The stakedAerodromeAM has a staked balance in aeroGauge.
        deal(address(aeroPool), address(stakedAerodromeAM), positionState.amountStaked);
        vm.startPrank(address(stakedAerodromeAM));
        aeroPool.approve(address(aeroGauge), positionState.amountStaked);
        aeroGauge.deposit(positionState.amountStaked);
        vm.stopPrank();

        // When: Account withdraws full position from stakingAM.
        // Then: The liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(aeroPool), positionState.amountStaked);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // And: Account should get the staking and reward tokens.
        assertEq(aeroPool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(AERO).balanceOf(account_), 0);

        // And: No claimed rewards are returned.
        assertEq(rewards, 0);

        // And: The positionId should be burned.
        assertEq(stakedAerodromeAM.balanceOf(account_), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
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
            givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max);

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

        // And: Position is minted to the Account.
        stakedAerodromeAM.mintIdTo(account_, positionId);

        // And: The stakedAerodromeAM has a staked balance in aeroGauge.
        deal(address(aeroPool), address(stakedAerodromeAM), positionState.amountStaked);
        vm.startPrank(address(stakedAerodromeAM));
        aeroPool.approve(address(aeroGauge), positionState.amountStaked);
        aeroGauge.deposit(positionState.amountStaked);
        vm.stopPrank();

        // And: The reward of the position is non-zero, and the Asset Module holds it.
        uint256 currentRewardAccount = stakedAerodromeAM.rewardOf(positionId);
        vm.assume(currentRewardAccount > 0);
        deal(AERO, address(stakedAerodromeAM), surplusState.lastRewardBalance + currentRewardAccount);

        // When: Account withdraws full position from stakingAM.
        // Then: The reward is paid out and the liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.RewardPaid(positionId, AERO, uint128(currentRewardAccount));
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.LiquidityDecreased(positionId, address(aeroPool), positionState.amountStaked);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // And: Account should get the staking and reward tokens.
        assertEq(aeroPool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(AERO).balanceOf(account_), currentRewardAccount);

        // And: Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And: Rewards have been claimed from the aeroGauge.
        assertEq(ERC20Mock(AERO).balanceOf(address(aeroGauge)), 0);

        // And: The positionId should be burned.
        assertEq(stakedAerodromeAM.balanceOf(account_), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerTokenGlobal(assetState));
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
            givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max);

        // And: Both accumulators start at zero, so the credited reward is the position's whole share.
        assetState.lastRewardPerTokenGlobal = 0;
        positionState.lastRewardPerTokenPosition = 0;

        // And: The rewardPerToken delta stays under its cap, above it the share is no longer proportional.
        assetState.currentRewardGlobal =
            bound(assetState.currentRewardGlobal, 1, FullMath.mulDiv(type(uint128).max, assetState.totalStaked, 1e18));

        // And: The reward the aeroGauge reports fits the uint128 a position accounts its share in.
        assetState.currentRewardGlobal = bound(assetState.currentRewardGlobal, 1, type(uint128).max);

        // And: The already credited reward leaves the new share room in that same uint128.
        uint256 deltaReward = FullMath.mulDiv(
            FullMath.mulDiv(assetState.currentRewardGlobal, 1e18, assetState.totalStaked),
            positionState.amountStaked,
            1e18
        );
        positionState.lastRewardPosition =
            uint128(bound(positionState.lastRewardPosition, 0, type(uint128).max - deltaReward));

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, surplusState, address(aeroPool), positionId);

        // And: Position is minted to the Account.
        stakedAerodromeAM.mintIdTo(account_, positionId);

        // And: The stakedAerodromeAM has a staked balance in aeroGauge.
        deal(address(aeroPool), address(stakedAerodromeAM), positionState.amountStaked);
        vm.startPrank(address(stakedAerodromeAM));
        aeroPool.approve(address(aeroGauge), positionState.amountStaked);
        aeroGauge.deposit(positionState.amountStaked);
        vm.stopPrank();

        // And: The position has a non-zero reward, its earned part already claimed by the stakedAerodromeAM.
        uint256 currentRewardAccount = stakedAerodromeAM.rewardOf(positionId);
        vm.assume(currentRewardAccount > 0);
        deal(AERO, address(stakedAerodromeAM), surplusState.lastRewardBalance + positionState.lastRewardPosition);

        // When: Account withdraws full position from stakingAM.
        // Then: The reward is paid out and the liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.RewardPaid(positionId, AERO, uint128(currentRewardAccount));
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.LiquidityDecreased(positionId, address(aeroPool), positionState.amountStaked);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // And: Account should get the staking and reward tokens.
        assertEq(aeroPool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(AERO).balanceOf(account_), currentRewardAccount);

        // And: The credited reward is the position's share, within the two floorings of 1e18 per stake.
        uint256 checkCurrentRewardAccount = positionState.lastRewardPosition
            + FullMath.mulDiv(positionState.amountStaked, assetState.currentRewardGlobal, assetState.totalStaked);
        assertApproxEqAbs(
            checkCurrentRewardAccount, currentRewardAccount, uint256(positionState.amountStaked) / 1e18 + 1
        );

        // And: Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And: The positionId should be burned.
        assertEq(stakedAerodromeAM.balanceOf(account_), 0);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(aeroPool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerTokenGlobal(assetState));
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }
}
