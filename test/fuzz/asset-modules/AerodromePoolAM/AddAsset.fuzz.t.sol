/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromePoolAM_Fuzz_Test } from "./_AerodromePoolAM.fuzz.t.sol";
import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "AerodromePoolAM".
 */
contract AddAsset_AerodromePoolAM_Fuzz_Test is AerodromePoolAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromePoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_addAsset_InvalidPool(address asset) public {
        // Given : The asset is not a pool in the the Aerodrome Factory.

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromePoolAM.InvalidPool.selector);
        aeroPoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed(address token0) public notTestContracts(token0) {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Volatile pool.
        aeroPoolMock.setStable(false);

        // Given : Token1 is added to the Registry, token0 is not.
        aeroPoolMock.setTokens(token0, address(mockERC20.token1));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        aeroPoolAM.addAsset(address(aeroPoolMock));
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed(address token1) public notTestContracts(token1) {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Volatile pool.
        aeroPoolMock.setStable(false);

        // Given : Token0 is added to the Registry, token1 is not.
        aeroPoolMock.setTokens(address(mockERC20.token1), token1);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        aeroPoolAM.addAsset(address(aeroPoolMock));
    }

    function testFuzz_Revert_addAsset_Stable_NotOwner(address sender) public {
        // Given : Valid initial state
        setMockState(true);

        // Given : sender is not the owner.
        vm.assume(sender != users.creatorAddress);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.prank(sender);
        vm.expectRevert(AerodromePoolAM.OnlyOwner.selector);
        aeroPoolAM.addAsset(address(aeroPoolMock));
    }

    function testFuzz_Success_addAsset_VolatilePool() public {
        // Given : Valid initial state
        setMockState(false);

        // When : An asset is added to the AM.
        aeroPoolAM.addAsset(address(aeroPoolMock));

        // Then : It should return the correct values
        assertTrue(registryExtension.inRegistry(address(aeroPoolMock)));
        assertTrue(aeroPoolAM.inAssetModule(address(aeroPoolMock)));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPoolMock)));
        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));

        // And : assetToInformation is empty.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) =
            aeroPoolAM.assetToInformation(address(aeroPoolMock));
        assertFalse(stable);
        assertEq(unitCorrection0, 0);
        assertEq(unitCorrection1, 0);
    }

    function testFuzz_Success_addAsset_StablePool() public {
        // Given : Valid initial state
        setMockState(true);

        // When : An asset is added to the AM by owner.
        vm.prank(users.creatorAddress);
        aeroPoolAM.addAsset(address(aeroPoolMock));

        // Then : It should return the correct values
        assertTrue(registryExtension.inRegistry(address(aeroPoolMock)));
        assertTrue(aeroPoolAM.inAssetModule(address(aeroPoolMock)));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPoolMock)));

        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));

        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) =
            aeroPoolAM.assetToInformation(address(aeroPoolMock));
        assertTrue(stable);
        assertEq(unitCorrection0, 10 ** (18 - mockERC20.token1.decimals()));
        assertEq(unitCorrection1, 10 ** (18 - mockERC20.stable1.decimals()));
    }
}
