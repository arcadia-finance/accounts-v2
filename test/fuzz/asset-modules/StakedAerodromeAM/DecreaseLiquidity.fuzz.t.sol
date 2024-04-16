/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import {
    StakedAerodromeAM_Fuzz_Test,
    AbstractStakingAM_Fuzz_Test,
    StakingAM,
    ERC20Mock
} from "./_StakedAerodromeAM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "StakedAerodromeAM".
 */
contract DecreaseLiquidity_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
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

    function testFuzz_Revert_decreaseLiquidity_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint128 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedAerodromeAM.decreaseLiquidity(id, amount);
    }

    function testFuzz_Revert_decreaseLiquidity_NotOwner(uint256 id, uint128 amount, address owner) public {
        // Given : Amount is greater than 0.
        vm.assume(amount > 0);

        // Given : Owner is not the caller.
        vm.assume(owner != users.accountOwner);

        // Given : Set owner of the specific positionId.
        stakedAerodromeAM.setOwnerOfPositionId(owner, id);

        // When : Trying to withdraw a position not owned by the caller.
        // Then : It should revert.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedAerodromeAM.decreaseLiquidity(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint128 amount
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And : Account has a non-zero balance.
        vm.assume(positionState.amountStaked > 0);
        // And : Account has a balance smaller as type(uint128).max.
        vm.assume(positionState.amountStaked < type(uint128).max);

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // Given : Position is minted to the Account
        stakedAerodromeAM.mintIdTo(account, positionId);

        // And: amount withdrawn is bigger than the balance.
        amount = uint128(bound(amount, positionState.amountStaked + 1, type(uint128).max));

        // When : Calling decreaseLiquidity().
        // Then : It should revert as remaining balance is too low.
        vm.startPrank(account);
        vm.expectRevert(stdError.arithmeticError);
        stakedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_FullWithdraw(
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // Given : Position is minted to the Account
        stakedAerodromeAM.mintIdTo(account, positionId);

        // And : stakedAerodromeAM has a staked balance in gauge
        deal(address(pool), address(stakedAerodromeAM), positionState.amountStaked);
        vm.startPrank(address(stakedAerodromeAM));
        pool.approve(address(gauge), positionState.amountStaked);
        gauge.deposit(positionState.amountStaked);
        vm.stopPrank();

        uint256 currentRewardAccount = stakedAerodromeAM.rewardOf(positionId);

        // And : Enough AERO is claimable in stakedAerodromeAM
        deal(AERO, address(stakedAerodromeAM), currentRewardAccount);

        // And reward is non-zero.
        vm.assume(currentRewardAccount > 0);

        // When : Account withdraws full position from stakingAM
        vm.startPrank(account);
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.RewardPaid(positionId, AERO, uint128(currentRewardAccount));
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.LiquidityDecreased(positionId, address(pool), positionState.amountStaked);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(pool.balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(AERO).balanceOf(account), currentRewardAccount);

        // And : Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And : Rewards have been claimed from the gauge
        assertEq(ERC20Mock(AERO).balanceOf(address(gauge)), 0);

        // And : positionId should be burned.
        assertEq(stakedAerodromeAM.balanceOf(account), 0);

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
            stakedAerodromeAM.assetState(address(pool));
        uint256 deltaReward = assetState.currentRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward * 1e18 / assetState.totalStaked);
        }
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_PartialWithdraw(
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint128 amount
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        uint256 currentRewardAccount;
        {
            // Given : Valid state
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And : Account has a balance bigger as 1.
            vm.assume(positionState.amountStaked > 1);

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

            // Given : Position is minted to the Account
            stakedAerodromeAM.mintIdTo(account, positionId);

            // And : stakedAerodromeAM has a staked balance in gauge
            deal(address(pool), address(stakedAerodromeAM), positionState.amountStaked);
            vm.startPrank(address(stakedAerodromeAM));
            pool.approve(address(gauge), positionState.amountStaked);
            gauge.deposit(positionState.amountStaked);
            vm.stopPrank();

            // And reward is non-zero.
            currentRewardAccount = stakedAerodromeAM.rewardOf(positionId);
            vm.assume(currentRewardAccount > 0);

            // And : Enough Aero is claimable in stakedAerodromeAM
            deal(AERO, address(stakedAerodromeAM), currentRewardAccount);
        }

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When : Account withdraws from stakingAM
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, AERO, uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(pool), amount);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(pool.balanceOf(account), amount);
        assertEq(ERC20Mock(AERO).balanceOf(account), currentRewardAccount);

        // And : Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And : Rewards have been claimed from the gauge
        assertEq(ERC20Mock(AERO).balanceOf(address(gauge)), 0);

        // And : positionId should not be burned.
        assertEq(stakedAerodromeAM.balanceOf(account), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
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
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_FullWithdraw(
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // Given : Position is minted to the Account
        stakedAerodromeAM.mintIdTo(account, positionId);

        // And : stakedAerodromeAM has a staked balance in gauge
        deal(address(pool), address(stakedAerodromeAM), positionState.amountStaked);
        vm.startPrank(address(stakedAerodromeAM));
        pool.approve(address(gauge), positionState.amountStaked);
        gauge.deposit(positionState.amountStaked);
        vm.stopPrank();

        // When : Account withdraws full position from stakingAM
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(pool), positionState.amountStaked);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(pool.balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(AERO).balanceOf(account), 0);

        // And : No claimed rewards are returned.
        assertEq(rewards, 0);

        // And : positionId should be burned.
        assertEq(stakedAerodromeAM.balanceOf(account), 0);

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
            stakedAerodromeAM.assetState(address(pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_PartialWithdraw(
        uint96 positionId,
        address account,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint128 amount
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        {
            // Given : Valid state
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And : Account has a balance bigger as 1.
            vm.assume(positionState.amountStaked > 1);

            // And reward is zero.
            positionState.lastRewardPosition = 0;
            positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
            assetState.currentRewardGlobal = 0;

            // And: State is persisted.
            setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

            // Given : Position is minted to the Account
            stakedAerodromeAM.mintIdTo(account, positionId);

            // And : stakedAerodromeAM has a staked balance in gauge
            deal(address(pool), address(stakedAerodromeAM), positionState.amountStaked);
            vm.startPrank(address(stakedAerodromeAM));
            pool.approve(address(gauge), positionState.amountStaked);
            gauge.deposit(positionState.amountStaked);
            vm.stopPrank();
        }

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When : Account withdraws from stakingAM
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, address(pool), amount);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(pool.balanceOf(account), amount);
        assertEq(ERC20Mock(AERO).balanceOf(account), 0);

        // And : No claimed rewards are returned.
        assertEq(rewards, 0);

        // And : positionId should not be burned.
        assertEq(stakedAerodromeAM.balanceOf(account), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedAerodromeAM.positionState(positionId);
        assertEq(newPositionState.asset, address(pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedAerodromeAM.assetState(address(pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    // Here we are validating that if we send just the right amount of previously earned rewards (lastRewardPosition) to the stakedAerodromeAM as well as just the right amount of currentRewardGlobal to the gauge, all the accounting is done right with correct amount of final rewards.
    function testFuzz_Success_decreaseLiquidity_NonZeroReward_FullWithdraw_RewardsAccounting(
        uint96 positionId,
        address account
    ) public canReceiveERC721(account) {
        vm.assume(account != address(0));

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.assume(account != address(pool));
        vm.assume(account != pool.poolFees());

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);
        vm.assume(account != address(gauge));
        vm.assume(account != address(voter));

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : Valid state
        StakingAMStateForAsset memory assetState = StakingAMStateForAsset({
            currentRewardGlobal: 123_456 * 1e18,
            lastRewardPerTokenGlobal: 0,
            totalStaked: 1_111_111 * 1e18
        });

        StakingAM.PositionState memory positionState = StakingAM.PositionState({
            asset: address(pool),
            amountStaked: 123_324 * 1e18,
            lastRewardPerTokenPosition: 0,
            lastRewardPosition: 1234 * 1e18
        });

        // And: State is persisted.
        setStakedAerodromeAMState(assetState, positionState, address(pool), positionId);

        // Given : Position is minted to the Account
        stakedAerodromeAM.mintIdTo(account, positionId);

        // And : stakedAerodromeAM has a staked balance in gauge
        deal(address(pool), address(stakedAerodromeAM), positionState.amountStaked);
        vm.startPrank(address(stakedAerodromeAM));
        pool.approve(address(gauge), positionState.amountStaked);
        gauge.deposit(positionState.amountStaked);
        vm.stopPrank();

        uint256 currentRewardAccount = stakedAerodromeAM.rewardOf(positionId);
        // And : Assume previously earned rewards were previously claimed by the stakedAerodromeAM
        deal(AERO, address(stakedAerodromeAM), positionState.lastRewardPosition);

        // And reward is non-zero.
        vm.assume(currentRewardAccount > 0);

        // When : Account withdraws full position from stakingAM
        vm.startPrank(account);
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.RewardPaid(positionId, AERO, uint128(currentRewardAccount));
        vm.expectEmit(true, true, true, true, address(stakedAerodromeAM));
        emit StakingAM.LiquidityDecreased(positionId, address(pool), positionState.amountStaked);
        uint256 rewards = stakedAerodromeAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(pool.balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(AERO).balanceOf(account), currentRewardAccount);

        uint256 checkCurrentRewardAccount = positionState.lastRewardPosition
            + uint256(positionState.amountStaked).mulDivDown(assetState.currentRewardGlobal, assetState.totalStaked);
        assertApproxEqAbs(checkCurrentRewardAccount, currentRewardAccount, 12_840); // 12_840 wei rounding errors on 14_936 * 1e18 currentRewards, minor

        // And : Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And : positionId should be burned.
        assertEq(stakedAerodromeAM.balanceOf(account), 0);

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
            stakedAerodromeAM.assetState(address(pool));
        uint256 deltaReward = assetState.currentRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward * 1e18 / assetState.totalStaked);
        }
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }
}
