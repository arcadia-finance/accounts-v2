/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StargateAssetModule".
 */
contract IsAllowed_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_True(uint256 positionId) public {
        // When : Calling isAllowed()
        bool allowed = stargateAssetModule.isAllowed(address(stargateAssetModule), positionId);

        // Then : It should return true
        assertEq(allowed, true);
    }

    function testFuzz_Success_isAllowed_False(uint256 positionId, address randomAddress) public {
        // When : Calling isAllowed() with the input address not equal to the Stargate AM
        bool allowed = stargateAssetModule.isAllowed(randomAddress, positionId);
        // Then : It should return false
        assertEq(allowed, false);
    }
}
