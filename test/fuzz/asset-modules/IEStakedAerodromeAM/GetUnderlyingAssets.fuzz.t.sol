/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IEStakedAerodromeAM_Fuzz_Test } from "./_IEStakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "IEStakedAerodromeAM".
 */
contract GetUnderlyingAssets_IEStakedAerodromeAM_Fuzz_Test is IEStakedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        IEStakedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(address underlyingAsset, uint96 positionId) public {
        // Given : Set Asset for positionId
        stakedAerodromeAM.setAssetInPosition(underlyingAsset, positionId);

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = stakedAerodromeAM.getKeyFromAsset(address(stakingAM), positionId);
        bytes32[] memory underlyingAssetKeys = stakedAerodromeAM.getUnderlyingAssets(assetKey);

        // Then : Underlying asset returned should be correct
        assertEq(underlyingAssetKeys.length, 1);
        assertEq(underlyingAssetKeys[0], stakedAerodromeAM.getKeyFromAsset(underlyingAsset, 0));
    }
}
