/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test } from "./_StargateAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "StargateAM".
 */
contract GetUnderlyingAssets_StargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets_InAssetModule(uint256 poolId) public {
        // And: pool is added
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.addAsset(poolId);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(poolMock)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](1);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));

        bytes32[] memory actualUnderlyingAssetKeys = stargateAssetModule.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule() public {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(poolMock)));

        bytes32[] memory underlyingAssetKeys = stargateAssetModule.getUnderlyingAssets(assetKey);

        // And: No actualUnderlyingAssetKeys are returned.
        assertEq(underlyingAssetKeys.length, 0);
    }
}
