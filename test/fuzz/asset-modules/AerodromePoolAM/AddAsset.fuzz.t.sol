/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

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
    function testFuzz_Revert_addAsset_Stable_NotOwner(address sender, address asset) public {
        // Given : sender is not the owner.
        vm.assume(sender != users.owner);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.prank(sender);
        vm.expectRevert("UNAUTHORIZED");
        aeroPoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_InvalidPool(address asset) public {
        // Given : The asset is not a aeroPool in the the Aerodrome Factory.
        vm.assume(asset != address(aeroPool));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.InvalidPool.selector);
        aeroPoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed(bool isStable, address token0) public canReceiveERC721(token0) {
        // Given : The asset is a aeroPool in the the Aerodrome Factory.
        aeroPoolFactory.setPool(address(aeroPool));

        // Given : The asset is an Aerodrome aeroPool.
        aeroPool.setStable(isStable);

        // Given : Token1 is added to the Registry, token0 is not.
        aeroPool.setTokens(token0, address(mockERC20.token1));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        aeroPoolAM.addAsset(address(aeroPool));
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed(bool isStable, address token1) public canReceiveERC721(token1) {
        // Given : The asset is a aeroPool in the the Aerodrome Factory.
        aeroPoolFactory.setPool(address(aeroPool));

        // Given : The asset is an Aerodrome Volatile aeroPool.
        aeroPool.setStable(isStable);

        // Given : Token0 is added to the Registry, token1 is not.
        aeroPool.setTokens(address(mockERC20.token1), token1);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        aeroPoolAM.addAsset(address(aeroPool));
    }

    function testFuzz_Success_addAsset_VolatilePool() public {
        // Given : Valid initial state
        aeroPool.setStable(false);

        // When : An asset is added to the AM.
        vm.prank(users.owner);
        aeroPoolAM.addAsset(address(aeroPool));

        // Then : It should return the correct values
        assertTrue(registry.inRegistry(address(aeroPool)));
        assertTrue(aeroPoolAM.inAssetModule(address(aeroPool)));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPool)));
        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);
        if (mockERC20.token1 < mockERC20.stable1) {
            assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
            assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));
        } else {
            assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));
            assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        }

        // And : assetToInformation is empty.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) = aeroPoolAM.assetToInformation(address(aeroPool));
        assertFalse(stable);
        assertEq(unitCorrection0, 0);
        assertEq(unitCorrection1, 0);
    }

    function testFuzz_Success_addAsset_StablePool() public {
        // Given : Valid initial state
        aeroPool.setStable(true);

        // When : An asset is added to the AM by owner.
        vm.prank(users.owner);
        aeroPoolAM.addAsset(address(aeroPool));

        // Then : It should return the correct values
        assertTrue(registry.inRegistry(address(aeroPool)));
        assertTrue(aeroPoolAM.inAssetModule(address(aeroPool)));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPool)));

        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);
        if (mockERC20.token1 < mockERC20.stable1) {
            assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
            assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));
        } else {
            assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));
            assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        }

        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) = aeroPoolAM.assetToInformation(address(aeroPool));
        assertTrue(stable);

        if (mockERC20.token1 < mockERC20.stable1) {
            assertEq(unitCorrection0, 10 ** (18 - mockERC20.token1.decimals()));
            assertEq(unitCorrection1, 10 ** (18 - mockERC20.stable1.decimals()));
        } else {
            assertEq(unitCorrection0, 10 ** (18 - mockERC20.stable1.decimals()));
            assertEq(unitCorrection1, 10 ** (18 - mockERC20.token1.decimals()));
        }
    }
}
