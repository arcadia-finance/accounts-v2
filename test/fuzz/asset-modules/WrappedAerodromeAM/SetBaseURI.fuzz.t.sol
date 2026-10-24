/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setBaseURI" of contract "WrappedAerodromeAM".
 */
contract SetBaseURI_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        // Given: The unprivileged address is not the owner of the Asset Module.
        vm.assume(address(unprivilegedAddress_) != users.owner);

        // When: The base URI is set.
        // Then: It reverts.
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        wrappedAerodromeAM.setBaseURI(uri);
        vm.stopPrank();
    }

    function testFuzz_Success_setBaseURI(string calldata uri) public {
        // Given: Any base URI.

        // When: The owner sets it.
        vm.prank(users.owner);
        wrappedAerodromeAM.setBaseURI(uri);

        // Then: The stored base URI is the new URI.
        assertEq(wrappedAerodromeAM.baseURI(), uri);
    }
}
