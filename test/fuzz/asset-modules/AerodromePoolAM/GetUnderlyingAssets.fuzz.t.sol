/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM_Fuzz_Test } from "./_AerodromePoolAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "AerodromePoolAM".
 */
contract GetUnderlyingAssets_AerodromePoolAM_Fuzz_Test is AerodromePoolAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromePoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets_InAssetModule(bool stable) public {
        // Given : Valid initial state
        aeroPool.setStable(stable);

        // And : Asset has been added to the AM
        vm.prank(users.owner);
        aeroPoolAM.addAsset(address(aeroPool));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPool)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        if (mockERC20.token1 < mockERC20.stable1) {
            expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
            expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        } else {
            expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
            expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        }

        bytes32[] memory actualUnderlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule() public {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPool)));

        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);

        // And: No actualUnderlyingAssetKeys are returned.
        assertEq(underlyingAssetKeys.length, 0);
    }
}
