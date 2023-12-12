/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "stake" of contract "StakingModule".
 */
contract Stake_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_stake_ZeroAmount() public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(StakingModule.ZeroAmount.selector);
        stakingModule.stake(0, 0);
    }

    function testFuzz_Success_stake(
        uint128 amount,
        address staker,
        uint8 underlyingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public notTestContracts(staker) {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);

        // Given : Two staking tokens are added to the stakingModule
        (address[] memory underlyingTokens,) = addStakingTokens(2, underlyingTokenDecimals, rewardTokenDecimals);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        mintERC20TokensTo(underlyingTokens, staker, amounts);
        approveERC20TokensFor(underlyingTokens, address(stakingModule), amounts, staker);

        // When :  A user is staking via the Staking Module
        vm.startPrank(staker);
        vm.expectEmit();
        emit StakingModule.Staked(staker, 1, amount);
        stakingModule.stake(1, amount);
        vm.expectEmit();
        emit StakingModule.Staked(staker, 2, amount);
        stakingModule.stake(2, amount);
        vm.stopPrank();

        // Then : Tokens should be transferred to the module and specific ERC1155 minted
        assertEq(stakingModule.balanceOf(staker, 1), amount);
        assertEq(stakingModule.balanceOf(staker, 2), amount);
        assertEq(ERC20Mock(underlyingTokens[0]).balanceOf(address(stakingModule)), amount);
        assertEq(ERC20Mock(underlyingTokens[1]).balanceOf(address(stakingModule)), amount);
        (,, uint128 totalSupply1) = stakingModule.tokenState(1);
        (,, uint128 totalSupply2) = stakingModule.tokenState(2);
        assertEq(totalSupply1, amount);
        assertEq(totalSupply2, amount);
    }
}
