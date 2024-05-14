/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "WrappedAerodromeAM".
 */
contract GetUnderlyingAssets_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(bool stable, uint96 positionId) public {
        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), stable);

        // And : Calling addAsset()
        wrappedAerodromeAM.addAsset(address(pool));

        // And : Set Asset for positionId
        wrappedAerodromeAM.setPoolInPosition(address(pool), positionId);

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = wrappedAerodromeAM.getKeyFromAsset(address(wrappedAerodromeAM), positionId);
        bytes32[] memory underlyingAssetKeys = wrappedAerodromeAM.getUnderlyingAssets(assetKey);

        // Then : Underlying assets returned should be correct
        assertEq(underlyingAssetKeys[0], wrappedAerodromeAM.getKeyFromAsset(address(pool), 0));
        assertEq(underlyingAssetKeys[1], wrappedAerodromeAM.getKeyFromAsset(address(mockERC20.token1), 0));
        assertEq(underlyingAssetKeys[2], wrappedAerodromeAM.getKeyFromAsset(address(mockERC20.stable1), 0));
    }
}
