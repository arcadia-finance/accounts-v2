/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { Strings } from "../../../../src/libraries/Strings.sol";

/**
 * @notice Fuzz tests for the function "setBaseURI" of contract "StakedMetadex03CLAM".
 */
contract SetBaseURI_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    using Strings for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        // Given: The caller is not the owner.
        vm.assume(unprivilegedAddress_ != users.owner);

        // When: The caller sets a new base URI.
        // Then: It reverts.
        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        stakedMetadex03CLAM.setBaseURI(uri);
    }

    function testFuzz_Success_setBaseURI(string calldata uriInitial, string calldata uri) public {
        // Given: A base URI is already stored.
        vm.prank(users.owner);
        stakedMetadex03CLAM.setBaseURI(uriInitial);

        // When: The owner sets a new base URI.
        vm.prank(users.owner);
        stakedMetadex03CLAM.setBaseURI(uri);

        // Then: The new base URI is stored.
        assertEq(stakedMetadex03CLAM.baseURI(), uri);
    }

    function testFuzz_Success_uriOfId(string calldata uri, uint256 id) public {
        // Given: A non-empty base URI is stored.
        vm.assume(bytes(uri).length > 0);
        vm.prank(users.owner);
        stakedMetadex03CLAM.setBaseURI(uri);

        // When: The token URI of an id is read.
        string memory actualUri = stakedMetadex03CLAM.tokenURI(id);

        // Then: The id is appended to the base URI.
        // forge-lint: disable-next-item(encode-packed-collision)
        assertEq(actualUri, string(abi.encodePacked(uri, id.toString())));
    }
}
