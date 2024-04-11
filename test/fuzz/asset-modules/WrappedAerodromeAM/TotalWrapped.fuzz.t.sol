/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

/**
 * @notice Fuzz tests for the function "totalWrapped" of contract "WrappedAerodromeAM".
 */
contract TotalWrapped_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_totalWrapped(WrappedAerodromeAM.PoolState memory poolState, address pool_) public {
        // Given : PoolState is set.
        wrappedAerodromeAM.setPoolState(pool_, poolState);

        // When : Calling totalWrapped() for the specific pool.
        // Then : It should return the correct amount.
        assertEq(wrappedAerodromeAM.totalWrapped(pool_), poolState.totalWrapped);
    }
}
