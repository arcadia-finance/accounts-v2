/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";
import { Strings } from "../../../../src/libraries/Strings.sol";

/**
 * @notice Fuzz tests for the function "setBaseURI" of contract "StargateAssetModule".
 */
contract SetBaseURI_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    using Strings for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        vm.assume(address(unprivilegedAddress_) != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        stargateAssetModule.setBaseURI(uri);
        vm.stopPrank();
    }

    function testFuzz_Success_setBaseURI(string calldata uri) public {
        vm.prank(users.creatorAddress);
        stargateAssetModule.setBaseURI(uri);

        string memory expectedUri = stargateAssetModule.baseURI();

        assertEq(expectedUri, uri);
    }

    function testFuzz_Success_UriOfId(string calldata uri, uint256 id) public {
        vm.assume(bytes(uri).length > 0);
        vm.prank(users.creatorAddress);
        stargateAssetModule.setBaseURI(uri);

        string memory actualUri = stargateAssetModule.tokenURI(id);

        assertEq(actualUri, string(abi.encodePacked(uri, id.toString())));
    }
}
