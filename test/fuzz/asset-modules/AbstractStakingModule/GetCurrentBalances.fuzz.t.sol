/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentBalances" of contract "StakingModule".
 */
contract GetCurrentBalances_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Success_getCurrentBalances_ZeroTotalSupply(
        StakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Valid state
        moduleState = setStakingModuleState(moduleState, id, account);

        // And: totalSupply is zero.
        stakingModule.setTotalSupply(id, 0);

        // When : Calling _getCurrentBalances()
        (uint256 currentRewardPerToken, uint256 currentRewardGlobal, uint256 totalSupply_, uint256 currentRewardAccount)
        = stakingModule.getCurrentBalances(account, id);

        // Then : It should return the correct values
        assertEq(currentRewardPerToken, 0);
        assertEq(currentRewardGlobal, 0);
        assertEq(totalSupply_, 0);
        assertEq(currentRewardAccount, 0);
    }

    function testFuzz_Success_getCurrentBalances_NonZeroTotalSupply_ZeroBalanceOf(
        StakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Valid state
        moduleState = setStakingModuleState(moduleState, id, account);

        // And: totalSupply is non-zero.
        vm.assume(moduleState.totalSupply > 0);

        // And: Account balance is zero.
        stakingModule.setBalanceOf(id, 0, account);

        // When : Calling _getCurrentBalances()
        (uint256 currentRewardPerToken, uint256 currentRewardGlobal, uint256 totalSupply_, uint256 currentRewardAccount)
        = stakingModule.getCurrentBalances(account, id);

        // Then : It should return the correct value
        uint256 deltaReward = moduleState.currentRewardGlobal - moduleState.lastRewardGlobal;
        uint256 rewardPerToken =
            moduleState.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, moduleState.totalSupply);

        assertEq(currentRewardPerToken, rewardPerToken);
        assertEq(currentRewardGlobal, moduleState.currentRewardGlobal);
        assertEq(totalSupply_, moduleState.totalSupply);
        assertEq(currentRewardAccount, 0);
    }

    function testFuzz_Success_getCurrentBalances_NonZeroTotalSupply_NonZeroBalanceOf(
        StakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Valid state
        moduleState = setStakingModuleState(moduleState, id, account);

        // And: Account balance is zero. (-> totalSupply is non-zero)
        vm.assume(moduleState.accountBalance > 0);

        // When : Calling _getCurrentBalances()
        (uint256 currentRewardPerToken, uint256 currentRewardGlobal, uint256 totalSupply_, uint256 currentRewardAccount)
        = stakingModule.getCurrentBalances(account, id);

        // Then : It should return the correct value
        uint256 deltaRewardGlobal = moduleState.currentRewardGlobal - moduleState.lastRewardGlobal;
        uint256 rewardPerToken =
            moduleState.lastRewardPerTokenGlobal + deltaRewardGlobal.mulDivDown(1e18, moduleState.totalSupply);
        uint256 deltaRewardPerToken = rewardPerToken - moduleState.lastRewardPerTokenAccount;
        uint256 currentRewardAccount_ =
            moduleState.lastRewardAccount + uint256(moduleState.accountBalance).mulDivDown(deltaRewardPerToken, 1e18);

        assertEq(currentRewardPerToken, rewardPerToken);
        assertEq(currentRewardGlobal, moduleState.currentRewardGlobal);
        assertEq(totalSupply_, moduleState.totalSupply);
        assertEq(currentRewardAccount, currentRewardAccount_);
    }
}
