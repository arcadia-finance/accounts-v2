/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "StakingModule".
 */
contract Burn_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_burn_NonZeroReward(
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

        // Given: Valid state
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And : Account has a non-zero balance.
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

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.RewardPaid(account, address(rewardTokens[0]), uint128(currentRewardAccount));
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked);
        stakingModule.burn(positionId);
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

    function testFuzz_Success_burn_ZeroReward(
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

        // Given: Valid state
        (assetState, positionState) = givenValidStakingModuleState(assetState, positionState);

        // And : Account has a non-zero balance.
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

        // When : Account withdraws from stakingModule
        vm.startPrank(account);
        vm.expectEmit();
        emit StakingModule.LiquidityDecreased(account, assets[0], positionState.amountStaked);
        stakingModule.burn(positionId);
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
}
