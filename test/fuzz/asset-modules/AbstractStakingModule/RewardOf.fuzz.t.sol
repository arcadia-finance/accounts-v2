/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "rewardOf" of contract "StakingModule".
 */
contract RewardOf_AbstractAbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_Success_rewardOf_ZeroBalanceOf(
        StakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Valid state
        moduleState = setStakingModuleState(moduleState, id, account);

        // And: Account balance is zero.
        stakingModule.setBalanceOf(id, 0, account);

        // When : Calling rewardOf()
        uint256 currentRewardAccount = stakingModule.rewardOf(account, id);

        // Then : It should return zero.
        assertEq(currentRewardAccount, 0);
    }

    function testFuzz_Success_rewardOf_NonZeroBalanceOf(
        StakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Valid state
        moduleState = setStakingModuleState(moduleState, id, account);

        // And: Account balance is non zero.
        vm.assume(moduleState.accountBalance > 0);

        // When : Calling rewardOf()
        uint256 currentRewardAccount = stakingModule.rewardOf(account, id);

        // Then : It should return the correct value
        uint256 deltaRewardGlobal = moduleState.currentRewardGlobal - moduleState.lastRewardGlobal;
        uint256 rewardPerToken =
            moduleState.lastRewardPerTokenGlobal + deltaRewardGlobal.mulDivDown(1e18, moduleState.totalSupply);
        uint256 deltaRewardPerToken = rewardPerToken - moduleState.lastRewardPerTokenAccount;
        uint256 currentRewardAccount_ =
            moduleState.lastRewardAccount + uint256(moduleState.accountBalance).mulDivDown(deltaRewardPerToken, 1e18);

        assertEq(currentRewardAccount, currentRewardAccount_);
    }
}
