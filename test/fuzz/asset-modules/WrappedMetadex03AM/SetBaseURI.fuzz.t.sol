/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setBaseURI" of contract "WrappedMetadex03AM".
 */
contract SetBaseURI_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
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
        wrappedMetadex03AM.setBaseURI(uri);
        vm.stopPrank();
    }

    function testFuzz_Success_setBaseURI(string calldata uri) public {
        // Given: Any base URI.

        // When: The owner sets it.
        vm.prank(users.owner);
        wrappedMetadex03AM.setBaseURI(uri);

        // Then: The stored base URI is the new URI.
        assertEq(wrappedMetadex03AM.baseURI(), uri);
    }
}
