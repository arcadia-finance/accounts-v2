/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "totalWrapped" of contract "WrappedMetadex03AM".
 */
contract TotalWrapped_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_totalWrapped(WrappedAerodromeAM.PoolState memory poolState, address pool_) public {
        // Given: The pool state of an arbitrary pool is seeded.
        wrappedMetadex03AM.setPoolState(pool_, poolState);

        // When: The total wrapped amount of that pool is read.
        // Then: The seeded amount is returned.
        assertEq(wrappedMetadex03AM.totalWrapped(pool_), poolState.totalWrapped);
    }
}
