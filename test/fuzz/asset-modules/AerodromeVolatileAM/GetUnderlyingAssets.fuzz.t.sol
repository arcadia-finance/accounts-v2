/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeVolatileAM_Fuzz_Test } from "./_AerodromeVolatileAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "AerodromeVolatileAM".
 */
contract GetUnderlyingAssets_AerodromeVolatileAM_Fuzz_Test is AerodromeVolatileAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeVolatileAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets_InAssetModule() public {
        // Given : Valid initial state
        setMockState();

        // And : Asset has been added to the AM
        aeroVolatileAM.addAsset(address(aeroPoolMock));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPoolMock)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));

        bytes32[] memory actualUnderlyingAssetKeys = aeroVolatileAM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule() public {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPoolMock)));

        bytes32[] memory underlyingAssetKeys = aeroVolatileAM.getUnderlyingAssets(assetKey);

        // And: No actualUnderlyingAssetKeys are returned.
        assertEq(underlyingAssetKeys.length, 0);
    }
}
