/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "StakingModule2".
 */
contract IsAllowed_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_isAllowed_False_BadAsset(uint256 positionId, address randomAddress) public {
        // Given : randomAddress is not the stakingModule.
        vm.assume(randomAddress != address(stakingModule));

        // When : Calling isAllowed() with the input address not equal to the Stargate AM
        bool allowed = stakingModule.isAllowed(randomAddress, positionId);

        // Then : It should return false
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_False_BadId(uint256 positionId, uint256 lastPositionId) public {
        // Given: positionId is bigger as lastPositionId.
        lastPositionId = bound(lastPositionId, 0, type(uint256).max - 1);
        positionId = bound(positionId, lastPositionId + 1, type(uint256).max);
        stakingModule.setIdCounter(lastPositionId);

        // When : Calling isAllowed()
        bool allowed = stakingModule.isAllowed(address(stakingModule), positionId);

        // Then : It should return true
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_True(uint256 positionId, uint256 lastPositionId) public {
        // Given: positionId is smaller or equal as lastPositionId.
        positionId = bound(positionId, 0, lastPositionId);
        stakingModule.setIdCounter(lastPositionId);

        // When : Calling isAllowed()
        bool allowed = stakingModule.isAllowed(address(stakingModule), positionId);

        // Then : It should return true
        assertTrue(allowed);
    }
}
