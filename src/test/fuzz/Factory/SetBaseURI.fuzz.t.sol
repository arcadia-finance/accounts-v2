/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, Factory_Fuzz_Test } from "./Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setBaseURI" of contract "Factory".
 */
contract SetBaseURI_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        vm.assume(address(unprivilegedAddress_) != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        factory.setBaseURI(uri);
        vm.stopPrank();
    }

    function testSuccess_setBaseURI(string calldata uri) public {
        vm.prank(users.creatorAddress);
        factory.setBaseURI(uri);

        string memory expectedUri = factory.baseURI();

        assertEq(expectedUri, uri);
    }
}
