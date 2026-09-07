/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM_Fuzz_Test } from "./_AerodromePoolAM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "AerodromePoolAM".
 */
contract IsAllowed_AerodromePoolAM_Fuzz_Test is AerodromePoolAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromePoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_False(address asset, uint256 id) public view {
        // Given: The asset is not in the Asset Module.

        // When: The asset is checked.
        bool allowed = aeroPoolAM.isAllowed(asset, id);

        // Then: It is not allowed.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_True(address asset, uint256 id) public {
        // Given: The asset is in the Asset Module.
        stdstore.target(address(aeroPoolAM)).sig(aeroPoolAM.inAssetModule.selector).with_key(asset).checked_write(true);

        // When: The asset is checked.
        bool allowed = aeroPoolAM.isAllowed(asset, id);

        // Then: It is allowed.
        assertTrue(allowed);
    }
}
