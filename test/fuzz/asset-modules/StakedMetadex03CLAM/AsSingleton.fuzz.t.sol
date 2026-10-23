/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_asSingleton" of contract "StakedMetadex03CLAM".
 */
contract AsSingleton_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_asSingleton(uint256 positionId) public view {
        // Given:

        // When: Calling _asSingleton().
        uint256[] memory positionIds = stakedMetadex03CLAM.asSingleton(positionId);

        // Then: The position id is the only element of the array.
        assertEq(positionIds.length, 1);
        assertEq(positionIds[0], positionId);
    }
}
