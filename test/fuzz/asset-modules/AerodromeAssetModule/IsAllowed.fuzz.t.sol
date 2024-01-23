/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test } from "./_AerodromeAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "AerodromeAssetModule".
 */
contract IsAllowed_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_True(uint256 positionId) public {
        // When : Calling isAllowed()
        bool allowed = aerodromeAssetModule.isAllowed(address(aerodromeAssetModule), positionId);

        // Then : It should return true
        assertEq(allowed, true);
    }

    function testFuzz_Success_isAllowed_False(uint256 positionId, address randomAddress) public {
        // When : Calling isAllowed() with the input address not equal to the Stargate AM
        bool allowed = aerodromeAssetModule.isAllowed(randomAddress, positionId);
        // Then : It should return false
        assertEq(allowed, false);
    }
}
