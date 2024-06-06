/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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

    function testFuzz_Success_isAllowed_False_BadAsset(address randomAddress, uint256 positionId) public {
        // Given : randomAddress is not the stakingAM.
        vm.assume(randomAddress != address(stakedSlipstreamAM));

        // When : Calling isAllowed() with the input address not equal to the Stargate AM
        bool allowed = stakedSlipstreamAM.isAllowed(randomAddress, positionId);

        // Then : It should return false
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadId(uint256 positionId) public {
        // Given: positionId is not minted.

        // When : Calling isAllowed()
        bool allowed = stakedSlipstreamAM.isAllowed(address(stakedSlipstreamAM), positionId);

        // Then : It should return true
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_True(address to, uint256 positionId) public {
        // Given: positionId is minted.
        stakedSlipstreamAM.mint(to, positionId);

        // When : Calling isAllowed()
        bool allowed = stakedSlipstreamAM.isAllowed(address(stakedSlipstreamAM), positionId);

        // Then : It should return true
        assertTrue(allowed);
    }
}
