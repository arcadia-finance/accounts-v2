/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeVolatileAM_Fuzz_Test } from "./_AerodromeVolatileAM.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../../lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "AerodromeVolatileAM".
 */
contract IsAllowed_AerodromeVolatileAM_Fuzz_Test is AerodromeVolatileAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeVolatileAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_False(address asset, uint256 id) public {
        // When : Calling isAllowed()
        bool allowed = aeroVolatileAM.isAllowed(asset, id);

        // Then : It should return false
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_True(address asset, uint256 id) public {
        // Given: asset is in the aeroVolatileAM.
        stdstore.target(address(aeroVolatileAM)).sig(aeroVolatileAM.inAssetModule.selector).with_key(asset)
            .checked_write(true);

        // When : Calling isAllowed()
        bool allowed = aeroVolatileAM.isAllowed(asset, id);

        // Then : It should return true
        assertTrue(allowed);
    }
}
