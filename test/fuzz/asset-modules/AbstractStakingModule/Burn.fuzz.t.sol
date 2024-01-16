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

    function testFuzz_Success_burn(
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
        stakingModule.burn(positionId);
        vm.stopPrank();

        // Then : Account should get the staking and reward tokens
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), positionState.amountStaked);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), currentRewardAccount);
        // And : positionId should be burned.
        assertEq(stakingModule.balanceOf(account), 0);
    }
}
