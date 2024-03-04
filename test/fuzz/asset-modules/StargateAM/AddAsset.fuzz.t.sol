/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test } from "./_StargateAM.fuzz.t.sol";
import { StargateAM } from "../../../../src/asset-modules/Stargate-Finance/StargateAM.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StargateAM".
 */
contract AddAsset_StargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_addAsset_InvalidPool(uint256 poolId, address sender) public {
        // Given : An Asset is already set.

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.prank(sender);
        vm.expectRevert(StargateAM.InvalidPool.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_UnderlyingAssetNotAllowed(uint256 poolId, address sender, address underlyingAsset)
        public
        notTestContracts(underlyingAsset)
    {
        // Given : Valid pool
        sgFactoryMock.setPool(poolId, address(poolMock));

        // And : underlyingAsset is not allowed
        poolMock.setToken(underlyingAsset);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(sender);
        vm.expectRevert(StargateAM.UnderlyingAssetNotAllowed.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint256 poolId, address sender) public {
        // Given : Valid pool
        sgFactoryMock.setPool(poolId, address(poolMock));

        // And : underlyingAsset is allowed
        poolMock.setToken(address(mockERC20.token1));

        // When : An Asset is added to AM.
        vm.prank(sender);
        stargateAssetModule.addAsset(poolId);

        // Then : Information should be set and correct
        assertTrue(registryExtension.inRegistry(address(poolMock)));

        assertTrue(stargateAssetModule.inAssetModule(address(poolMock)));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(poolMock)));
        bytes32[] memory underlyingAssetKeys = stargateAssetModule.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
    }
}
