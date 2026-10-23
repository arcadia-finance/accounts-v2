/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "WrappedMetadex03AM".
 */
contract GetUnderlyingAssets_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(bool stable, uint96 positionId) public {
        // Given: A pool that is allowed in the Registry.
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), stable);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));

        // And: The pool is added as an asset.
        wrappedMetadex03AM.addAsset(address(metadex03Pool));

        // And: The position holds that pool.
        wrappedMetadex03AM.setPoolInPosition(address(metadex03Pool), positionId);

        // When: The underlying assets of the position are read.
        bytes32 assetKey = wrappedMetadex03AM.getKeyFromAsset(address(wrappedMetadex03AM), positionId);
        bytes32[] memory underlyingAssetKeys = wrappedMetadex03AM.getUnderlyingAssets(assetKey);

        // Then: The pool is the first underlying asset.
        assertEq(underlyingAssetKeys[0], wrappedMetadex03AM.getKeyFromAsset(address(metadex03Pool), 0));

        // And: Both pool tokens follow in sorted order.
        if (address(mockERC20.token1) < address(mockERC20.stable1)) {
            assertEq(underlyingAssetKeys[1], wrappedMetadex03AM.getKeyFromAsset(address(mockERC20.token1), 0));
            assertEq(underlyingAssetKeys[2], wrappedMetadex03AM.getKeyFromAsset(address(mockERC20.stable1), 0));
        } else {
            assertEq(underlyingAssetKeys[1], wrappedMetadex03AM.getKeyFromAsset(address(mockERC20.stable1), 0));
            assertEq(underlyingAssetKeys[2], wrappedMetadex03AM.getKeyFromAsset(address(mockERC20.token1), 0));
        }
    }
}
