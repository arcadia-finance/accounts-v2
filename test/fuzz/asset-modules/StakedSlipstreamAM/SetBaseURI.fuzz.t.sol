/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { Strings } from "../../../../src/libraries/Strings.sol";

/**
 * @notice Fuzz tests for the function "setBaseURI" of contract "StakedSlipstreamAM".
 */
contract SetBaseURI_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    using Strings for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        vm.assume(address(unprivilegedAddress_) != users.owner);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        stakedSlipstreamAM.setBaseURI(uri);
        vm.stopPrank();
    }

    function testFuzz_Success_setBaseURI(string calldata uri) public {
        vm.prank(users.owner);
        stakedSlipstreamAM.setBaseURI(uri);

        string memory expectedUri = stakedSlipstreamAM.baseURI();

        assertEq(expectedUri, uri);
    }

    function testFuzz_Success_UriOfId(string calldata uri, uint256 id) public {
        vm.assume(bytes(uri).length > 0);
        vm.prank(users.owner);
        stakedSlipstreamAM.setBaseURI(uri);

        string memory actualUri = stakedSlipstreamAM.tokenURI(id);

        assertEq(actualUri, string(abi.encodePacked(uri, id.toString())));
    }
}
