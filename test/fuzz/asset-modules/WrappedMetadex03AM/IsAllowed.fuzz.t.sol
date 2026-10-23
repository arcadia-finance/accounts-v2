/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "WrappedMetadex03AM".
 */
contract IsAllowed_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_False_BadAsset(uint256 positionId, address randomAddress) public view {
        // Given: The random address is not the Asset Module.
        vm.assume(randomAddress != address(wrappedMetadex03AM));

        // When: The isAllowed check runs for the random address.
        bool allowed = wrappedMetadex03AM.isAllowed(randomAddress, positionId);

        // Then: It returns false.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadId(uint256 positionId, uint256 lastPositionId) public {
        // Given: The position id is bigger than the last minted position id.
        lastPositionId = bound(lastPositionId, 0, type(uint256).max - 1);
        positionId = bound(positionId, lastPositionId + 1, type(uint256).max);
        wrappedMetadex03AM.setIdCounter(lastPositionId);

        // When: The isAllowed check runs for the Asset Module and that position id.
        bool allowed = wrappedMetadex03AM.isAllowed(address(wrappedMetadex03AM), positionId);

        // Then: It returns false.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_True(uint256 positionId, uint256 lastPositionId) public {
        // Given: The position id is smaller than or equal to the last minted position id.
        positionId = bound(positionId, 0, lastPositionId);
        wrappedMetadex03AM.setIdCounter(lastPositionId);

        // When: The isAllowed check runs for the Asset Module and that position id.
        bool allowed = wrappedMetadex03AM.isAllowed(address(wrappedMetadex03AM), positionId);

        // Then: It returns true.
        assertTrue(allowed);
    }
}
