/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, StakingModuleErrors, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "stake" of contract "AbstractStakingModule".
 */
contract Stake_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_revert_stake_ZeroAmount() public {
        vm.expectRevert(StakingModuleErrors.AmountIsZero.selector);
        stakingModule.stake(0, 0);
    }

    function testFuzz_success_stake(uint256 decimals, uint256 amount, address staker) public {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);
        decimals = bound(decimals, 6, 18);

        // Given : Two staking tokens are added to the stakingModule
        (address[] memory stakingTokens,) = addStakingTokens(2, uint8(decimals), uint8(decimals));

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        mintTokensTo(stakingTokens, staker, amounts);
        approveTokensFor(stakingTokens, address(stakingModule), amounts, staker);

        // When :  A user is staking via the Staking Module
        // Note: add events
        vm.startPrank(staker);
        stakingModule.stake(1, amount);
        stakingModule.stake(2, amount);
        vm.stopPrank();

        // Then : Tokens should be transferred to the module and specific ERC1155 minted
        assertEq(stakingModule.balanceOf(staker, 1), amount);
        assertEq(stakingModule.balanceOf(staker, 2), amount);
        assertEq(ERC20Mock(stakingTokens[0]).balanceOf(address(stakingModule)), amount);
        assertEq(ERC20Mock(stakingTokens[1]).balanceOf(address(stakingModule)), amount);
        assertEq(stakingModule.totalSupply_(1), amount);
        assertEq(stakingModule.totalSupply_(2), amount);
    }
}
