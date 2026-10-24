/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";
import { Constants } from "../../Fuzz.t.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract DecreaseLiquidity_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_decreaseLiquidity_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint128 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakingAM.decreaseLiquidity(id, amount);
    }

    function testFuzz_Revert_decreaseLiquidity_NotOwner(uint256 id, uint128 amount, address owner) public {
        // Given : Amount is greater than 0.
        amount = uint128(bound(amount, 1, type(uint128).max));

        // Given : Owner is not the caller.
        vm.assume(owner != users.accountOwner);

        // Given : Set owner of the specific positionId.
        stakingAM.setOwnerOfPositionId(owner, id);

        // When : Trying to withdraw a position not owned by the caller.
        // Then : It should revert.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakingAM.decreaseLiquidity(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        address asset,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));
        // Given : Valid state
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max - 1);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // Given : Position is minted to the Account
        stakingAM.mintIdTo(account_, positionId);

        // And: amount withdrawn is bigger than the balance.
        amount = uint128(bound(amount, positionState.amountStaked + 1, type(uint128).max));

        // When : Calling decreaseLiquidity().
        // Then : It should revert as remaining balance is too low.
        vm.startPrank(account_);
        vm.expectRevert(stdError.arithmeticError);
        stakingAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_FullWithdraw(
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
        // Given : Add an Asset + reward token pair
        (address asset) = addAsset(assetDecimals);
        vm.assume(account_ != asset);

        // Given : Valid state
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 1, type(uint128).max);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // Given : Position is minted to the Account
        stakingAM.mintIdTo(account_, positionId);

        // Given : transfer Asset and rewardToken to stakingAM, as _withdrawAndClaim and _claimReward are not implemented on external staking contract
        // And reward is non-zero.
        deal(asset, address(stakingAM), positionState.amountStaked, true);
        uint256 currentRewardAccount = stakingAM.rewardOf(positionId);
        vm.assume(currentRewardAccount > 0);
        deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + currentRewardAccount, true);

        // When : Account withdraws full position from stakingAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(rewardToken), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, positionState.amountStaked);
        uint256 rewards = stakingAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(asset).balanceOf(account_), positionState.amountStaked);
        assertEq(rewardToken.balanceOf(account_), currentRewardAccount);

        // And : Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

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

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_PartialWithdraw(
        uint8 assetDecimals,
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount
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

            // Given : Valid state
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 2, type(uint128).max);

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

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When : Account withdraws from stakingAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(rewardToken), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, amount);
        uint256 rewards = stakingAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(ERC20Mock(asset).balanceOf(account_), amount);
        assertEq(rewardToken.balanceOf(account_), currentRewardAccount);

        // And : Claimed rewards are returned.
        assertEq(rewards, currentRewardAccount);

        // And : positionId should not be burned.
        assertEq(stakingAM.balanceOf(account_), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        uint128 currentRewardPerToken = currentRewardPerTokenGlobal(assetState);
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_FullWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public canReceiveERC721(account_) {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));
        // Given : Add an Asset + reward token pair
        (address asset) = addAsset(assetDecimals);
        vm.assume(account_ != asset);

        // Given : Valid state
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
        // And reward is non-zero.
        deal(asset, address(stakingAM), positionState.amountStaked, true);

        // When : Account withdraws full position from stakingAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, positionState.amountStaked);
        uint256 rewards = stakingAM.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(asset).balanceOf(account_), positionState.amountStaked);
        assertEq(rewardToken.balanceOf(account_), 0);

        // And : No claimed rewards are returned.
        assertEq(rewards, 0);

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

    function testFuzz_Success_decreaseLiquidity_ZeroReward_PartialWithdraw(
        uint8 assetDecimals,
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount
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

            // Given : Valid state
            (assetState, positionState) =
                givenValidStakingAMState(assetState, positionState, surplusState, 2, type(uint128).max);

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

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When : Account withdraws from stakingAM
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityDecreased(positionId, asset, amount);
        uint256 rewards = stakingAM.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(ERC20Mock(asset).balanceOf(account_), amount);
        assertEq(rewardToken.balanceOf(account_), 0);

        // And : No claimed rewards are returned.
        assertEq(rewards, 0);

        // And : positionId should not be burned.
        assertEq(stakingAM.balanceOf(account_), 1);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingAM.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_decreaseLiquidity_ValidAccountingFlow(
        StakingAMStateForSurplus memory surplusState,
        uint128 user1InitBalance,
        uint128 user2InitBalance,
        uint128 user1AddedBalance,
        uint128 user3Balance,
        uint128 rewardAmount1,
        uint128 rewardAmount2
    ) public {
        // Given : Every stake is non-zero, and all four together fit the uint128 total staked of the Asset.
        user1InitBalance = uint128(bound(user1InitBalance, 1, type(uint128).max - 3));
        user2InitBalance = uint128(bound(user2InitBalance, 1, type(uint128).max - user1InitBalance - 2));
        user1AddedBalance =
            uint128(bound(user1AddedBalance, 1, type(uint128).max - user1InitBalance - user2InitBalance - 1));
        user3Balance = uint128(
            bound(user3Balance, 1, type(uint128).max - user1InitBalance - user2InitBalance - user1AddedBalance)
        );

        // And : User2 accumulates both tranches, which together have to fit its uint128 reward balance.
        rewardAmount1 = uint128(bound(rewardAmount1, 1, type(uint128).max - 1));
        rewardAmount2 = uint128(bound(rewardAmount2, 1, type(uint128).max - rewardAmount1));

        // And : The rewardPerToken the Asset Module accumulates over each tranche.
        uint128 rewardPerToken1;
        uint128 deltaRewardPerToken2;
        {
            StakingAMStateForAsset memory assetState;
            assetState.totalStaked = user1InitBalance + user2InitBalance;
            assetState.currentRewardGlobal = rewardAmount1;
            rewardPerToken1 = currentRewardPerTokenGlobal(assetState);

            assetState.totalStaked = assetState.totalStaked + user1AddedBalance;
            assetState.currentRewardGlobal = rewardAmount2;
            assetState.lastRewardPerTokenGlobal = rewardPerToken1;
            unchecked {
                deltaRewardPerToken2 = currentRewardPerTokenGlobal(assetState) - rewardPerToken1;
            }
        }

        address asset = address(mockERC20.stable1);
        stakingAM.addAsset(asset);
        address user3 = address(0x3);

        // And : Valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);

        // And : Both users stake in the stakingAM.
        deal(asset, address(0x1), user1InitBalance, true);
        vm.startPrank(address(0x1));
        ERC20Mock(asset).approve(address(stakingAM), user1InitBalance);
        stakingAM.mint(asset, user1InitBalance);
        vm.stopPrank();

        deal(asset, address(0x2), user2InitBalance, true);
        vm.startPrank(address(0x2));
        ERC20Mock(asset).approve(address(stakingAM), user2InitBalance);
        stakingAM.mint(asset, user2InitBalance);
        vm.stopPrank();

        // And : A first reward tranche accrues over both stakes.
        stakingAM.setActualRewardBalance(asset, rewardAmount1);

        // When : User1 claims.
        // Then : He receives his share of the first tranche.
        vm.prank(address(0x1));
        stakingAM.claimReward(1);
        uint256 expectedUser1Reward = uint256(rewardPerToken1) * user1InitBalance / Constants.WAD;
        assertEq(rewardToken.balanceOf(address(0x1)), expectedUser1Reward);

        // And : User1 stakes additional Assets.
        deal(asset, address(0x1), user1AddedBalance, true);
        vm.startPrank(address(0x1));
        ERC20Mock(asset).approve(address(stakingAM), user1AddedBalance);
        stakingAM.increaseLiquidity(1, user1AddedBalance);
        vm.stopPrank();

        // And : A second reward tranche accrues.
        stakingAM.setActualRewardBalance(asset, rewardAmount2);

        // And : User3 stakes after the second tranche accrued.
        deal(asset, user3, user3Balance, true);
        vm.startPrank(user3);
        ERC20Mock(asset).approve(address(stakingAM), user3Balance);
        uint256 positionId3 = stakingAM.mint(asset, user3Balance);
        vm.stopPrank();

        // When : User1 withdraws his full position.
        // Then : He receives his share of the second tranche on top of the first.
        vm.prank(address(0x1));
        stakingAM.decreaseLiquidity(1, user1InitBalance + user1AddedBalance);

        expectedUser1Reward += uint256(deltaRewardPerToken2) * (user1InitBalance + user1AddedBalance) / Constants.WAD;
        assertEq(rewardToken.balanceOf(address(0x1)), expectedUser1Reward);
        assertEq(ERC20Mock(asset).balanceOf(address(0x1)), user1InitBalance + user1AddedBalance);

        // When : User2 withdraws his full position.
        // Then : He receives his share of both tranches.
        vm.prank(address(0x2));
        stakingAM.decreaseLiquidity(2, user2InitBalance);

        uint128 rewardPerToken2;
        unchecked {
            rewardPerToken2 = rewardPerToken1 + deltaRewardPerToken2;
        }
        assertEq(rewardToken.balanceOf(address(0x2)), uint256(rewardPerToken2) * user2InitBalance / Constants.WAD);
        assertEq(ERC20Mock(asset).balanceOf(address(0x2)), user2InitBalance);

        // When : User3 claims.
        // Then : He accrued nothing, he was not staked while either tranche accrued.
        vm.prank(user3);
        stakingAM.claimReward(positionId3);
        assertEq(rewardToken.balanceOf(user3), 0);

        // And: The reward token balance is cached.
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_decreaseLiquidity_BookedSurplusNotCredited(
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

        // When: The owner withdraws its full position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakingAM.decreaseLiquidity(positionId, amount);

        // Then: The owner is paid the delivered reward less the booked part.
        assertEq(rewards, expectedReward);
        assertEq(rewardToken.balanceOf(users.liquidityProvider), expectedReward);

        // And: The booked amount is not credited to the position.
        assertEq(stakingAM.bookedSurplus(), surplusState.bookedSurplus + booked);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }
}
