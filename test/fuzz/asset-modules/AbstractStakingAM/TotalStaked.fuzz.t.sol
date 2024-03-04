/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "totalStaked" of contract "StakingAM".
 */
contract TotalStaked_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_totalStaked(uint128 totalStaked, address asset) public {
        // Given : Total staked for Asset is set in stakingAM.
        stakingAM.setTotalStaked(asset, totalStaked);

        // When : Calling totalStaked() for the specific Asset.
        // Then : It should return the correct amount.
        assertEq(stakingAM.totalStaked(asset), totalStaked);
    }
}
