/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Strings } from "../../../../src/libraries/Strings.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "tokenURI" of contract "WrappedMetadex03AM".
 */
contract TokenURI_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    using Strings for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_tokenURI_NonEmptyBaseURI(string calldata uri, uint256 id) public {
        // Given: The base URI is not empty.
        vm.assume(bytes(uri).length > 0);
        vm.prank(users.owner);
        wrappedMetadex03AM.setBaseURI(uri);

        // When: The token URI of a position is read.
        string memory actualUri = wrappedMetadex03AM.tokenURI(id);

        // Then: The base URI is concatenated with the position id.
        // forge-lint: disable-next-item(encode-packed-collision)
        assertEq(actualUri, string(abi.encodePacked(uri, id.toString())));
    }
}
