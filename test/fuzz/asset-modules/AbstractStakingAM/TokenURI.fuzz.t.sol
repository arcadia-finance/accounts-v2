/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";
import { Strings } from "../../../../src/libraries/Strings.sol";

/**
 * @notice Fuzz tests for the function "tokenURI" of contract "StakingAM".
 */
contract TokenURI_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
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

    function testFuzz_Success_tokenURI_NonEmptyBaseURI(string calldata uri, uint256 id) public {
        // Given : The baseURI is not empty.
        vm.assume(bytes(uri).length > 0);
        vm.prank(users.owner);
        stakingAM.setBaseURI(uri);

        // When : Calling tokenURI().
        string memory actualUri = stakingAM.tokenURI(id);

        // Then : The baseURI is concatenated with the id.
        // forge-lint: disable-next-item(encode-packed-collision)
        assertEq(actualUri, string(abi.encodePacked(uri, id.toString())));
    }

    function testFuzz_Success_tokenURI_EmptyBaseURI(uint256 id) public {
        // Given : The baseURI is empty.
        vm.prank(users.owner);
        stakingAM.setBaseURI("");

        // When : Calling tokenURI().
        // Then : An empty string is returned.
        assertEq(stakingAM.tokenURI(id), "");
    }
}
