/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "earnedByAccount" of contract "AbstractStakingModule".
 */
contract EarnedByAccount_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_success_earnedByAccount(
        AbstractStakingModuleStateForId memory moduleState,
        uint256 id,
        address account,
        uint256 stakingTokenDecimals
    ) public {
        // Given : Valid state
        AbstractStakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Staking token decimals is min 6 and max 18
        stakingTokenDecimals = bound(stakingTokenDecimals, 6, 18);
        stakingModule.setStakingTokensDecimals(id, uint8(stakingTokenDecimals));

        // When : Calling earnedByAccount()
        uint256 earned = stakingModule.earnedByAccount(id, account);

        // Then : It should return the correct value
        // rewardPerToken() is previously tested
        uint256 rewardPerToken = stakingModule.rewardPerToken(id);
        uint256 rewardPerTokenClaimable = rewardPerToken - moduleState_.userRewardPerTokenPaid;
        uint256 earned_ = moduleState_.rewards
            + uint256(moduleState.userBalance).mulDivDown(rewardPerTokenClaimable, 10 ** stakingTokenDecimals);

        assertEq(earned, earned_);
    }
}
