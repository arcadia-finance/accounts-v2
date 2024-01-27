/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";
import { Strings } from "../../../../src/libraries/Strings.sol";

/**
 * @notice Fuzz tests for the function "setBaseURI" of contract "StakingAM".
 */
contract SetBaseURI_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    using Strings for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setBaseURI_NonOwner(string calldata uri, address unprivilegedAddress_) public {
        vm.assume(address(unprivilegedAddress_) != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        stakingAM.setBaseURI(uri);
        vm.stopPrank();
    }

    function testFuzz_Success_setBaseURI(string calldata uri) public {
        vm.prank(users.creatorAddress);
        stakingAM.setBaseURI(uri);

        string memory expectedUri = stakingAM.baseURI();

        assertEq(expectedUri, uri);
    }

    function testFuzz_Success_UriOfId(string calldata uri, uint256 id) public {
        vm.assume(bytes(uri).length > 0);
        vm.prank(users.creatorAddress);
        stakingAM.setBaseURI(uri);

        string memory actualUri = stakingAM.tokenURI(id);

        assertEq(actualUri, string(abi.encodePacked(uri, id.toString())));
    }
}
