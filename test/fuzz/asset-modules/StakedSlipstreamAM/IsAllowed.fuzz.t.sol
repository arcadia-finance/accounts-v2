/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StakedSlipstreamAM".
 */
contract IsAllowed_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_True(address to, uint256 positionId) public canReceiveERC721(to) {
        // Given: The position id is minted.
        stakedSlipstreamAM.mint(to, positionId);

        // When: isAllowed() is called for the Asset Module itself.
        bool allowed = stakedSlipstreamAM.isAllowed(address(stakedSlipstreamAM), positionId);

        // Then: It returns true.
        assertTrue(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadAsset(address to, address randomAddress, uint256 positionId)
        public
        canReceiveERC721(to)
    {
        // Given: The position id is minted.
        stakedSlipstreamAM.mint(to, positionId);

        // And: The asset is not the Asset Module.
        vm.assume(randomAddress != address(stakedSlipstreamAM));

        // When: isAllowed() is called.
        bool allowed = stakedSlipstreamAM.isAllowed(randomAddress, positionId);

        // Then: It returns false.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadId(address to, uint256 positionId, uint256 positionIdMinted)
        public
        canReceiveERC721(to)
    {
        // Given: Another position id is minted.
        vm.assume(positionIdMinted != positionId);
        stakedSlipstreamAM.mint(to, positionIdMinted);

        // When: isAllowed() is called for a position id that was not minted.
        bool allowed = stakedSlipstreamAM.isAllowed(address(stakedSlipstreamAM), positionId);

        // Then: It returns false.
        assertFalse(allowed);
    }
}
