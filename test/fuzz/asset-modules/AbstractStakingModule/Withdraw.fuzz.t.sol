/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, ERC20Mock, StakingModuleErrors } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "AbstractStakingModule".
 */
contract Withdraw_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Revert_Withdraw_ZeroAmount(uint256 id) public {
        // Given : Amount is 0.
        uint256 amount = 0;

        // When : Trying to withdraw zero amount.
        // Then : It should revert.
        vm.expectRevert(StakingModuleErrors.AmountIsZero.selector);
        stakingModule.withdraw(id, amount);
    }

    function testFuzz_Success_Withdraw(address account, AbstractStakingModuleStateForId memory moduleState) public {
        // Given : id = 2
        uint256 id = 2;

        // Given : Valid state
        AbstractStakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Add a staking token + reward token pairs
        (address[] memory stakingTokens, address[] memory rewardTokens) = addStakingTokens(2);

        // Given : Account has a positive balance
        vm.assume(stakingModule.balanceOf(account, id) > 0);

        // Given : transfer stakingToken and rewardToken to stakingModule, as _withdraw and _claimRewards are not implemented on external staking contract.
        address[] memory tokens = new address[](2);
        tokens[0] = stakingTokens[1];
        tokens[1] = rewardTokens[1];

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = moduleState_.userBalance;
        uint256 earnedRewards = stakingModule.earnedByAccount(id, account);
        amounts[1] = earnedRewards;

        mintTokensTo(tokens, address(stakingModule), amounts);

        // When : Account withdraws from stakingModule
        // Note : Check for emitted event
        vm.prank(account);
        stakingModule.withdraw(id, moduleState_.userBalance);

        // Then : Account should get the staking and reward tokens.
        assertEq(ERC20Mock(tokens[0]).balanceOf(account), moduleState_.userBalance);
        assertEq(ERC20Mock(tokens[1]).balanceOf(account), earnedRewards);
        assertEq(stakingModule.balanceOf(account, id), 0);
    }
}
