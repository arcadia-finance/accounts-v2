/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "WrappedAerodromeAM".
 */
contract IsAllowed_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_False_BadAsset(uint256 positionId, address randomAddress) public {
        // Given : randomAddress is not the stakingAM.
        vm.assume(randomAddress != address(wrappedAerodromeAM));

        // When : Calling isAllowed() with the input address not equal to the Stargate AM
        bool allowed = wrappedAerodromeAM.isAllowed(randomAddress, positionId);

        // Then : It should return false
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadId(uint256 positionId, uint256 lastPositionId) public {
        // Given: positionId is bigger as lastPositionId.
        lastPositionId = bound(lastPositionId, 0, type(uint256).max - 1);
        positionId = bound(positionId, lastPositionId + 1, type(uint256).max);
        wrappedAerodromeAM.setIdCounter(lastPositionId);

        // When : Calling isAllowed()
        bool allowed = wrappedAerodromeAM.isAllowed(address(wrappedAerodromeAM), positionId);

        // Then : It should return true
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_True(uint256 positionId, uint256 lastPositionId) public {
        // Given: positionId is smaller or equal as lastPositionId.
        positionId = bound(positionId, 0, lastPositionId);
        wrappedAerodromeAM.setIdCounter(lastPositionId);

        // When : Calling isAllowed()
        bool allowed = wrappedAerodromeAM.isAllowed(address(wrappedAerodromeAM), positionId);

        // Then : It should return true
        assertTrue(allowed);
    }
}
