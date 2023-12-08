/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test, AbstractStakingModule, ERC20Mock } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "stake" of contract "AbstractStakingModule".
 */
contract Stake_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_stake_Reentered(uint256 id, uint128 amount) public {
        // Given : Reentrancy guard is in locked state.
        stakingModule.setLocked(2);

        // When : A user stakes.
        // Then : It should revert.
        vm.expectRevert(AbstractStakingModule.NoReentry.selector);
        stakingModule.stake(id, amount);
        vm.stopPrank();
    }

    function testFuzz_revert_stake_ZeroAmount() public {
        // The stake function should revert when trying to stake 0 amount.
        vm.expectRevert(AbstractStakingModule.AmountIsZero.selector);
        stakingModule.stake(0, 0);
    }

    function testFuzz_success_stake(
        uint128 amount,
        address staker,
        uint8 stakingTokenDecimals,
        uint8 rewardTokenDecimals
    ) public {
        // Given : Can't stake zero amount
        vm.assume(amount > 0);

        // Given : Two staking tokens are added to the stakingModule
        (address[] memory stakingTokens,) = addStakingTokens(2, stakingTokenDecimals, rewardTokenDecimals);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        mintERC20TokensTo(stakingTokens, staker, amounts);
        approveERC20TokensFor(stakingTokens, address(stakingModule), amounts, staker);

        // When :  A user is staking via the Staking Module
        vm.startPrank(staker);
        vm.expectEmit();
        emit AbstractStakingModule.Staked(staker, 1, amount);
        stakingModule.stake(1, amount);
        vm.expectEmit();
        emit AbstractStakingModule.Staked(staker, 2, amount);
        stakingModule.stake(2, amount);
        vm.stopPrank();

        // Then : Tokens should be transferred to the module and specific ERC1155 minted
        assertEq(stakingModule.balanceOf(staker, 1), amount);
        assertEq(stakingModule.balanceOf(staker, 2), amount);
        assertEq(ERC20Mock(stakingTokens[0]).balanceOf(address(stakingModule)), amount);
        assertEq(ERC20Mock(stakingTokens[1]).balanceOf(address(stakingModule)), amount);
        (,, uint128 totalSupply1) = stakingModule.idToInfo(1);
        (,, uint128 totalSupply2) = stakingModule.idToInfo(2);
        assertEq(totalSupply1, amount);
        assertEq(totalSupply2, amount);
    }
}
