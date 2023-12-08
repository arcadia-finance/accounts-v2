/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "rewardPerToken" of contract "AbstractStakingModule".
 */
contract RewardPerToken_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
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

    function testFuzz_success_rewardPerToken_totalSupplyIsZero(
        AbstractStakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Valid state
        AbstractStakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // Given : Total supply is 0
        stakingModule.setTotalSupply(id, 0);

        // When : Calling rewardPerToken()
        uint256 rewardPerToken = stakingModule.rewardPerToken(id);

        // Then : It should return the correct value
        assertEq(rewardPerToken, moduleState_.rewardPerTokenStored);
    }

    function testFuzz_success_rewardPerToken_totalSupplyNonZero(
        AbstractStakingModuleStateForId memory moduleState,
        uint256 id,
        address account
    ) public {
        // Given : Total supply is > 0 (totalSupply should be >= userBalance)
        vm.assume(moduleState.userBalance > 0);

        // Given : Valid state
        AbstractStakingModuleStateForId memory moduleState_ = setStakingModuleState(moduleState, id, account);

        // When : Calling rewardPerToken()
        uint256 rewardPerToken = stakingModule.rewardPerToken(id);

        // Then : It should return the correct value
        uint256 initialRewardPerToken = moduleState_.rewardPerTokenStored;
        uint256 earnedSinceLastUpdate = moduleState_.actualRewardBalance - moduleState_.previousRewardBalance;
        uint256 earnedPerTokenSinceLastUpdate = earnedSinceLastUpdate.mulDivDown(1e18, moduleState_.totalSupply);
        uint256 rewardPerToken_ = initialRewardPerToken + earnedPerTokenSinceLastUpdate;

        assertEq(rewardPerToken, rewardPerToken_);
    }
}
