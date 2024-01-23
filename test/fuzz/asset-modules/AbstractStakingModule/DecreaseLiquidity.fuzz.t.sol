/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

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

    function testFuzz_Revert_decreaseLiquidity_RemainingBalanceTooLow(
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        address asset,
        uint128 amount
    ) public {
        // Given : Valid state
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And : Account has a non-zero balance.
        vm.assume(positionState.amountStaked > 0);
        // And : Account has a balance smaller as type(uint128).max.
        vm.assume(positionState.amountStaked < type(uint128).max);

        // And: State is persisted.
        setStakingModuleState(assetState, positionState, asset, positionId);

        // Given : Position is minted to the Account
        stakingModule.mintIdTo(account, positionId);

        // And: amount withdrawn is bigger than the balance.
        amount = uint128(bound(amount, positionState.amountStaked + 1, type(uint128).max));

        // When : Calling decreaseLiquidity().
        // Then : It should revert as remaining balance is too low.
        vm.startPrank(account);
        vm.expectRevert(stdError.arithmeticError);
        stakingModule.decreaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_FullWithdraw(
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));
        vm.assume(account != address(stakingModule));

        // Given : Add an Asset + reward token pair
        (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);
        vm.assume(account != assets[0]);
        vm.assume(account != rewardTokens[0]);

        // Given : Valid state
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And: State is persisted.
        setStakingModuleState(assetState, positionState, assets[0], positionId);

        // Given : Position is minted to the Account
        stakingModule.mintIdTo(account, positionId);

        // Given : transfer Asset and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract
        address[] memory tokens = new address[](2);
        tokens[0] = assets[0];
        tokens[1] = rewardTokens[0];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = positionState.amountStaked;
        uint256 currentRewardAccount = stakingModule.rewardOf(positionId);
        amounts[1] = currentRewardAccount;

        // And reward is non-zero.
        vm.assume(currentRewardAccount > 0);

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws full position from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.RewardPaid(account, address(rewardTokens[0]), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked);
        stakingModule.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), currentRewardAccount);

        // And : positionId should be burned.
        assertEq(stakingModule.balanceOf(account), 0);

        // And: Asset state should be updated correctly.
        StakingModule.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(assets[0]);
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward * 1e18 / assetState.totalStaked);
        }
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_NonZeroReward_PartialWithdraw(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint128 amount
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));
        vm.assume(account != address(stakingModule));

        address asset;
        address rewardToken;
        uint256 currentRewardAccount;
        {
            // Given : Add an Asset + reward token pair
            (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);
            vm.assume(account != assets[0]);
            vm.assume(account != rewardTokens[0]);
            asset = assets[0];
            rewardToken = rewardTokens[0];

            // Given : Valid state
            (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

            // And : Account has a balance bigger as 1.
            vm.assume(positionState.amountStaked > 1);

            // And: State is persisted.
            setStakingModuleState(assetState, positionState, assets[0], positionId);

            // Given : Position is minted to the Account
            stakingModule.mintIdTo(account, positionId);

            // Given : transfer Asset and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract
            address[] memory tokens = new address[](2);
            tokens[0] = assets[0];
            tokens[1] = rewardTokens[0];

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = positionState.amountStaked;
            currentRewardAccount = stakingModule.rewardOf(positionId);
            amounts[1] = currentRewardAccount;

            // And reward is non-zero.
            vm.assume(currentRewardAccount > 0);

            mintERC20TokensTo(tokens, address(stakingModule), amounts);
        }

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.RewardPaid(account, address(rewardToken), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, asset, amount);
        stakingModule.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(ERC20Mock(asset).balanceOf(account), amount);
        assertEq(ERC20Mock(rewardToken).balanceOf(account), currentRewardAccount);

        // And : positionId should not be burned.
        assertEq(stakingModule.balanceOf(account), 1);

        // And: Position state should be updated correctly.
        StakingModule.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        uint256 deltaReward = assetState.currentRewardGlobal - assetState.lastRewardGlobal;
        uint128 currentRewardPerToken;
        unchecked {
            currentRewardPerToken =
                assetState.lastRewardPerTokenGlobal + uint128(deltaReward.mulDivDown(1e18, assetState.totalStaked));
        }
        assertEq(newPositionState.lastRewardPerTokenPosition, currentRewardPerToken);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingModule.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, currentRewardPerToken);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - amount);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_FullWithdraw(
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint8 assetDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));
        vm.assume(account != address(stakingModule));

        // Given : Add an Asset + reward token pair
        (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);
        vm.assume(account != assets[0]);
        vm.assume(account != rewardTokens[0]);

        // Given : Valid state
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And : Account has a non-zero balance
        vm.assume(positionState.amountStaked > 0);

        // And reward is zero.
        positionState.lastRewardPosition = 0;
        positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
        assetState.currentRewardGlobal = assetState.lastRewardGlobal;

        // And: State is persisted.
        setStakingModuleState(assetState, positionState, assets[0], positionId);

        // Given : Position is minted to the Account
        stakingModule.mintIdTo(account, positionId);

        // Given : transfer Asset and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract
        address[] memory tokens = new address[](2);
        tokens[0] = assets[0];
        tokens[1] = rewardTokens[0];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = positionState.amountStaked;

        mintERC20TokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws full position from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked);
        stakingModule.decreaseLiquidity(positionId, positionState.amountStaked);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), 0);

        // And : positionId should be burned.
        assertEq(stakingModule.balanceOf(account), 0);

        // And: Asset state should be updated correctly.
        StakingModule.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(assets[0]);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.lastRewardGlobal, 0);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);
    }

    function testFuzz_Success_decreaseLiquidity_ZeroReward_PartialWithdraw(
        uint8 assetDecimals,
        uint8 rewardTokenDecimals,
        uint256 positionId,
        address account,
        StakingModuleStateForAsset memory assetState,
        StakingModule.PositionState memory positionState,
        uint128 amount
    ) public notTestContracts(account) {
        // Given : account != zero address
        vm.assume(account != address(0));
        vm.assume(account != address(stakingModule));

        address asset;
        address rewardToken;
        {
            // Given : Add an Asset + reward token pair
            (address[] memory assets, address[] memory rewardTokens) = addAssets(1, assetDecimals, rewardTokenDecimals);
            vm.assume(account != assets[0]);
            vm.assume(account != rewardTokens[0]);
            asset = assets[0];
            rewardToken = rewardTokens[0];

            // Given : Valid state
            (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

            // And : Account has a balance bigger as 1.
            vm.assume(positionState.amountStaked > 1);

            // And reward is zero.
            positionState.lastRewardPosition = 0;
            positionState.lastRewardPerTokenPosition = assetState.lastRewardPerTokenGlobal;
            assetState.currentRewardGlobal = assetState.lastRewardGlobal;

            // And: State is persisted.
            setStakingModuleState(assetState, positionState, assets[0], positionId);

            // Given : Position is minted to the Account
            stakingModule.mintIdTo(account, positionId);

            // Given : transfer Asset and rewardToken to stakingModule, as _withdraw and _claimReward are not implemented on external staking contract
            address[] memory tokens = new address[](2);
            tokens[0] = assets[0];
            tokens[1] = rewardTokens[0];

            uint256[] memory amounts = new uint256[](2);
            amounts[0] = positionState.amountStaked;

            mintERC20TokensTo(tokens, address(stakingModule), amounts);
        }

        // And : amount withdrawn is smaller as the staked balance.
        amount = uint128(bound(amount, 1, positionState.amountStaked - 1));

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, asset, amount);
        stakingModule.decreaseLiquidity(positionId, amount);
        vm.stopPrank();

        // Then : Account should get the withdrawed amount and reward tokens.
        assertEq(ERC20Mock(asset).balanceOf(account), amount);
        assertEq(ERC20Mock(rewardToken).balanceOf(account), 0);

        // And : positionId should not be burned.
        assertEq(stakingModule.balanceOf(account), 1);

        // And: Position state should be updated correctly.
        StakingModule.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakingModule.positionState(positionId);
        assertEq(newPositionState.asset, asset);
        assertEq(newPositionState.amountStaked, positionState.amountStaked - amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And : Asset values should be updated correctly
        StakingModule.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.lastRewardGlobal, newAssetState.totalStaked) =
            stakingModule.assetState(asset);
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.lastRewardGlobal, 0);
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
