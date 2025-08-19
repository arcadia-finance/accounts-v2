/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AbstractStakingAM_Fuzz_Test, StakingAM, ERC20Mock } from "./_AbstractStakingAM.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "StakingAM".
 */
contract DecreaseLiquidity_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    using FixedPointMathLib for uint256;

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
        vm.assume(amount > 0);

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
        address asset,
        uint128 amount
    ) public canReceiveERC721(account_) {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));
        // Given : Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And : Account has a non-zero balance.
        vm.assume(positionState.amountStaked > 0);
        // And : Account has a balance smaller as type(uint128).max.
        vm.assume(positionState.amountStaked < type(uint128).max);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, asset, positionId);

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
        StakingAM.PositionState memory positionState
    ) public canReceiveERC721(account_) {
        // Given : account_ != zero address
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakingAM));
        vm.assume(account_ != address(rewardToken));
        // Given : Add an Asset + reward token pair
        (address asset) = addAsset(assetDecimals);
        vm.assume(account_ != asset);

        // Given : Valid state
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, asset, positionId);

        // Given : Position is minted to the Account
        stakingAM.mintIdTo(account_, positionId);

        // Given : transfer Asset and rewardToken to stakingAM, as _withdrawAndClaim and _claimReward are not implemented on external staking contract
        // And reward is non-zero.
        deal(asset, address(stakingAM), positionState.amountStaked, true);
        uint256 currentRewardAccount = stakingAM.rewardOf(positionId);
        vm.assume(currentRewardAccount > 0);
        deal(address(rewardToken), address(stakingAM), currentRewardAccount, true);

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
        uint8 assetDecimals,
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
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
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And : Account has a balance bigger as 1.
            vm.assume(positionState.amountStaked > 1);

            // And: State is persisted.
            setStakingAMState(assetState, positionState, asset, positionId);

            // Given : Position is minted to the Account
            stakingAM.mintIdTo(account_, positionId);

            // Given : transfer Asset and rewardToken to stakingAM, as _withdrawAndClaim and _claimReward are not implemented on external staking contract
            // And reward is non-zero.
            deal(asset, address(stakingAM), positionState.amountStaked, true);
            currentRewardAccount = stakingAM.rewardOf(positionId);
            vm.assume(currentRewardAccount > 0);
            deal(address(rewardToken), address(stakingAM), currentRewardAccount, true);
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
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken = assetState.lastRewardPerTokenGlobal
                + uint128(assetState.currentRewardGlobal.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) = stakingAM.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_FullWithdraw(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
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
        (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = 0;

        // And: State is persisted.
        setStakingAMState(assetState, positionState, asset, positionId);

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
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_PartialWithdraw(
        uint8 assetDecimals,
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
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
            (assetState, positionState) = givenValidStakingAMState(assetState, positionState);

            // And : Account has a balance bigger as 1.
            vm.assume(positionState.amountStaked > 1);

            // And reward is zero.
            positionState.lastRewardPosition = 0;
            positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
            assetState.currentRewardGlobal = 0;

            // And: State is persisted.
            setStakingAMState(assetState, positionState, asset, positionId);

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
    }

    function testFuzz_Success_decreaseLiquidity_ValidAccountingFlow() public {
        // Given : 2 actors and initial Asset amounts
        address user1 = address(0x1);
        address user2 = address(0x2);
        uint128 user1InitBalance = uint128(1_000_000 * (10 ** Constants.stableDecimals));
        uint128 user2InitBalance = uint128(4_000_000 * (10 ** Constants.stableDecimals));

        // Given : Fund both users with amount of Assets
        address asset = address(mockERC20.stable1);
        deal(asset, user1, user1InitBalance, true);
        deal(asset, user2, user2InitBalance, true);

        // Given : Add asset to stakingAM
        stakingAM.addAsset(asset);

        // Given : Both users stake in the stakingAM
        vm.prank(user1);
        ERC20Mock(asset).approve(address(stakingAM), user1InitBalance);
        vm.prank(user2);
        ERC20Mock(asset).approve(address(stakingAM), user2InitBalance);

        vm.prank(user1);
        stakingAM.mint(asset, user1InitBalance);
        vm.prank(user2);
        stakingAM.mint(asset, user2InitBalance);

        // Given : Mock rewards
        uint128 rewardAmount1 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingAM.setActualRewardBalance(asset, rewardAmount1);
        deal(address(rewardToken), address(stakingAM), type(uint256).max, true);

        // When : User1 claims rewards
        // Then : He should receive 1/5 of the rewardAmount1
        vm.prank(user1);
        stakingAM.claimReward(1);

        assertEq(rewardToken.balanceOf(user1), rewardAmount1 / 5);

        // Given : User 1 stakes additional tokens and stakes
        uint128 user1AddedBalance = uint128(3_000_000 * (10 ** Constants.stableDecimals));
        deal(asset, user1, user1AddedBalance, true);
        vm.prank(user1);
        ERC20Mock(asset).approve(address(stakingAM), user1AddedBalance);

        vm.prank(user1);
        stakingAM.increaseLiquidity(1, user1AddedBalance);

        // Given : Add 1 mio more rewards
        uint128 rewardAmount2 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingAM.setActualRewardBalance(asset, rewardAmount2);

        // Given : A third user stakes while there is no reward increase (this shouldn't accrue rewards for him and not impact other user rewards)
        address user3 = address(0x3);
        deal(asset, user3, user1AddedBalance, true);
        vm.prank(user3);
        ERC20Mock(asset).approve(address(stakingAM), user1AddedBalance);

        vm.prank(user3);
        stakingAM.mint(asset, user1AddedBalance);

        // When : User1 withdraws
        // Then : He should receive half of rewardAmount2
        vm.prank(user1);
        stakingAM.decreaseLiquidity(1, user1InitBalance + user1AddedBalance);

        assertEq(rewardToken.balanceOf(user1), (rewardAmount1 / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user1), user1InitBalance + user1AddedBalance);

        // When : User2 withdraws
        // Then : He should receive 4/5 of rewards1 + 1/2 of rewards2
        vm.prank(user2);
        stakingAM.decreaseLiquidity(2, user2InitBalance);

        assertEq(rewardToken.balanceOf(user2), ((4 * rewardAmount1) / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user2), user2InitBalance);

        // When : User3 calls getRewards()
        // Then : He should not have accrued any rewards
        vm.prank(user3);
        stakingAM.claimReward(3);

        assertEq(rewardToken.balanceOf(user3), 0);
    }
}
