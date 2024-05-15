/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "isRewardPresent" of contract "WrappedAM".
 */
contract IsRewardPresent_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_isRewardPresent_True(address[2] calldata currentRewards) public {
        // Given : Reward is in currentRewards
        address reward = currentRewards[1];

        // When : calling isRewardPresent()
        bool isPresent = wrappedAM.isRewardPresent(Utils.castArrayStaticToDynamic(currentRewards), reward);

        // Then : It should return true
        assertEq(true, isPresent);
    }

    function testFuzz_success_isRewardPresent_False(address[2] calldata currentRewards, address reward) public {
        // Given : Reward is in currentRewards
        vm.assume(reward != currentRewards[0]);
        vm.assume(reward != currentRewards[1]);

        // When : calling isRewardPresent()
        bool isPresent = wrappedAM.isRewardPresent(Utils.castArrayStaticToDynamic(currentRewards), reward);

        // Then : It should return false
        assertEq(false, isPresent);
    }
}
