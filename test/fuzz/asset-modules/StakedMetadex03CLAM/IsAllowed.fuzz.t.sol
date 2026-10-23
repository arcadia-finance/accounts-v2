/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StakedMetadex03CLAM".
 */
contract IsAllowed_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_True(address to, uint256 positionId) public canReceiveERC721(to) {
        // Given: The position id is minted.
        stakedMetadex03CLAM.mint(to, positionId);

        // When: isAllowed() is called for the Asset Module itself.
        bool allowed = stakedMetadex03CLAM.isAllowed(address(stakedMetadex03CLAM), positionId);

        // Then: It returns true.
        assertTrue(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadAsset(address to, address randomAddress, uint256 positionId)
        public
        canReceiveERC721(to)
    {
        // Given: The position id is minted.
        stakedMetadex03CLAM.mint(to, positionId);

        // And: The asset is not the Asset Module.
        vm.assume(randomAddress != address(stakedMetadex03CLAM));

        // When: isAllowed() is called.
        bool allowed = stakedMetadex03CLAM.isAllowed(randomAddress, positionId);

        // Then: It returns false.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadId(address to, uint256 positionId, uint256 positionIdMinted)
        public
        canReceiveERC721(to)
    {
        // Given: Another position id is minted.
        vm.assume(positionIdMinted != positionId);
        stakedMetadex03CLAM.mint(to, positionIdMinted);

        // When: isAllowed() is called for a position id that was not minted.
        bool allowed = stakedMetadex03CLAM.isAllowed(address(stakedMetadex03CLAM), positionId);

        // Then: It returns false.
        assertFalse(allowed);
    }
}
