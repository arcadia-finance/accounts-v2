/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "decreaseLiquidity" of contract "StakingModule".
 */
contract DecreaseLiquidity_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_decreaseLiquidity_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint128 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.decreaseLiquidity(id, amount);
    }

    function testFuzz_Revert_decreaseLiquidity_NotOwner(uint256 id, uint128 amount, address owner) public {
        // Given : Amount is greater than 0.
        vm.assume(amount > 0);

        // Given : Owner is not the caller.
        vm.assume(owner != users.accountOwner);

        // Given : Set owner of the specific positionId.
        stakingModule.setOwnerOfPositionId(owner, id);

        // When : Trying to withdraw a position not owned by the caller.
        // Then : It should revert.
        vm.startPrank(users.accountOwner);
        vm.expectRevert(StakingModule.NotOwner.selector);
        stakingModule.decreaseLiquidity(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(uint256 id, uint128 amount, address owner)
        public
    {
        // Given : Amount is greater than 0.
        vm.assume(amount > 0);
        // Given : Owner is the caller.
        stakingModule.setOwnerOfPositionId(owner, id);
        // Given : Remaining amount in position is smaller than amount to withdraw.
        stakingModule.setAmountStakedForPosition(id, amount - 1);
        // When : Calling withdraw().
        // Then : It should revert as remaining balance is too low.
        vm.startPrank(owner);
        vm.expectRevert(StakingModule.RemainingBalanceTooLow.selector);
        stakingModule.decreaseLiquidity(id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_CurrentRewardPositionGreaterThan0(
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : Add an Asset + reward token pair
        (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, assets[0], positionId);

        // Given : Position is minted to the Account
        stakingModule.mintIdTo(account, positionId);

        // Given : Account has a positive balance
        (, uint128 amountStaked,,) = stakingModule.positionState(positionId);
        vm.assume(amountStaked > 0);

        // Given : transfer Asset and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract
        address[] memory tokens = new address[](2);
        tokens[0] = assets[0];
        tokens[1] = rewardTokens[0];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = positionState.amountStaked;
        uint256 currentRewardAccount = stakingModule.rewardOf(positionId);
        amounts[1] = currentRewardAccount;

        // Given : CurrentRewardAccount is greater than 0
        vm.assume(currentRewardAccount > 0);

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked);
        stakingModule.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), currentRewardAccount);
        // And : positionId should be burned.
        assertEq(stakingModule.balanceOf(account), 0);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroCurrentRewardPosition(
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : Add an Asset + reward token pairs
        (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);
        address asset = assets[0];

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : Position is minted to the Account
        stakingModule.mintIdTo(account, positionId);

        // Given : Account has a positive balance
        (, uint128 amountStaked,,) = stakingModule.positionState(positionId);
        vm.assume(amountStaked > 0);

        // Given : No rewards have accrued for Asset
        // CurrentRewardGlobal is equal to lastRewardGlobal
        stakingModule.setActualRewardBalance(asset, assetState.lastRewardGlobal);
        // LastRewardPerTokenGlobal is equal to lastRewardPerTokenPosition
        stakingModule.setLastRewardPerTokenGlobal(asset, positionState.lastRewardPerTokenPosition);
        // LastRewardPosition is 0
        stakingModule.setLastRewardPosition(positionId, 0);

        // Given : transfer Asset to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract
        address[] memory tokens = new address[](1);
        tokens[0] = assets[0];

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = positionState.amountStaked;
        uint256 currentRewardAccount = stakingModule.rewardOf(positionId);

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        assertEq(currentRewardAccount, 0);

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked);
        stakingModule.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the amount of Asset staked and reward tokens
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(rewardTokens[0]).balanceOf(account), 0);
        // And : positionId should be burned.
        assertEq(stakingModule.balanceOf(account), 0);
    }

    function testFuzz_Success_decreaseLiquidity_PartialWithdraw(
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));

        // Given : Add an Asset + reward token pairs
        (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);

        // Given : Valid state
        (assetState, positionState) = setStakingModuleState(assetState, positionState, assets[0], positionId);

        // Given : Position is minted to Account
        stakingModule.mintIdTo(account, positionId);

        // Given : Position has a positive balance greater than 1 (to be able to withdraw partially)
        (, uint128 amountStaked,,) = stakingModule.positionState(positionId);
        vm.assume(amountStaked > 1);

        // Given : transfer Asset and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract.
        address[] memory tokens = new address[](2);
        tokens[0] = assets[0];
        tokens[1] = rewardTokens[0];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = positionState.amountStaked;
        uint256 currentRewardAccount = stakingModule.rewardOf(positionId);
        amounts[1] = currentRewardAccount;

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked - 1);
        stakingModule.decreaseLiquidity(positionId, positionState.amountStaked - 1);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked - 1);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), currentRewardAccount);
        // And : positionId should not be burned.
        assertEq(stakingModule.balanceOf(account), 1);
        // And : Amount staked remaining in position should be correct.
        (, amountStaked,,) = stakingModule.positionState(positionId);
        assertEq(amountStaked, 1);
    }

    function testFuzz_Success_decreaseLiquidity_ValidAccountingFlow() public {
        // Given : 2 actors and initial Asset amounts
        address user1 = address(0x1);
        address user2 = address(0x2);
        uint128 user1InitBalance = uint128(1_000_000 * (10 ** Constants.stableDecimals));
        uint128 user2InitBalance = uint128(4_000_000 * (10 ** Constants.stableDecimals));

        // Given : Fund both users with amount of Assets
        address asset = address(mockERC20.stable1);
        address rewardToken = address(mockERC20.token1);
        mintERC20TokenTo(asset, user1, user1InitBalance);
        mintERC20TokenTo(asset, user2, user2InitBalance);

        // Given : Add asset and rewardToken to stakingModule
        stakingModule.setAssetAndRewardToken(asset, mockERC20.token1);

        // Given : Both users stake in the stakingModule
        approveERC20TokenFor(asset, address(stakingModule), user1InitBalance, user1);
        approveERC20TokenFor(asset, address(stakingModule), user2InitBalance, user2);

        vm.prank(user1);
        stakingModule.mint(asset, user1InitBalance);
        vm.prank(user2);
        stakingModule.mint(asset, user2InitBalance);

        // Given : Mock rewards
        uint128 rewardAmount1 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingModule.setActualRewardBalance(asset, rewardAmount1);
        mintERC20TokenTo(rewardToken, address(stakingModule), type(uint256).max);

        // When : User1 claims rewards
        // Then : He should receive 1/5 of the rewardAmount1
        vm.prank(user1);
        stakingModule.claimReward(1);

        assertEq(mockERC20.token1.balanceOf(user1), rewardAmount1 / 5);

        // Given : User 1 stakes additional tokens and stakes
        uint128 user1AddedBalance = uint128(3_000_000 * (10 ** Constants.stableDecimals));
        mintERC20TokenTo(asset, user1, user1AddedBalance);
        approveERC20TokenFor(asset, address(stakingModule), user1AddedBalance, user1);

        vm.prank(user1);
        stakingModule.increaseLiquidity(1, user1AddedBalance);

        // Given : Add 1 mio more rewards
        uint128 rewardAmount2 = uint128(1_000_000 * (10 ** Constants.tokenDecimals));
        stakingModule.setActualRewardBalance(asset, rewardAmount2);

        // Given : A third user stakes while there is no reward increase (this shouldn't accrue rewards for him and not impact other user rewards)
        address user3 = address(0x3);
        mintERC20TokenTo(asset, user3, user1AddedBalance);
        approveERC20TokenFor(asset, address(stakingModule), user1AddedBalance, user3);

        vm.prank(user3);
        stakingModule.mint(asset, user1AddedBalance);

        // When : User1 withdraws
        // Then : He should receive half of rewardAmount2
        vm.prank(user1);
        stakingModule.decreaseLiquidity(1, user1InitBalance + user1AddedBalance);

        assertEq(mockERC20.token1.balanceOf(user1), (rewardAmount1 / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user1), user1InitBalance + user1AddedBalance);

        // When : User2 withdraws
        // Then : He should receive 4/5 of rewards1 + 1/2 of rewards2
        vm.prank(user2);
        stakingModule.decreaseLiquidity(2, user2InitBalance);

        assertEq(mockERC20.token1.balanceOf(user2), ((4 * rewardAmount1) / 5) + (rewardAmount2 / 2));
        assertEq(mockERC20.stable1.balanceOf(user2), user2InitBalance);

        // When : User3 calls getRewards()
        // Then : He should not have accrued any rewards
        vm.prank(user3);
        stakingModule.claimReward(3);

        assertEq(mockERC20.token1.balanceOf(user3), 0);
    }
}
