/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeStableAM_Fuzz_Test } from "./_AerodromeStableAM.fuzz.t.sol";
import { AerodromeStableAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeStableAM.sol";
import { AerodromeVolatileAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "AerodromeStableAM".
 */
contract AddAsset_AerodromeStableAM_Fuzz_Test is AerodromeStableAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeStableAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_addAsset_InvalidPool(address asset) public {
        // Given : The asset is not a pool in the the Aerodrome Factory.

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromeVolatileAM.InvalidPool.selector);
        aeroStableAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_IsNotAStablePool() public {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Volatile pool.
        aeroPoolMock.setStable(false);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromeStableAM.IsNotAStablePool.selector);
        aeroStableAM.addAsset(address(aeroPoolMock));
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed(address token1) public notTestContracts(token1) {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Stable pool.
        aeroPoolMock.setStable(true);

        // Given : Token0 is added to the Registry, token1 is not.
        aeroPoolMock.setTokens(address(mockERC20.token1), token1);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromeVolatileAM.AssetNotAllowed.selector);
        aeroStableAM.addAsset(address(aeroPoolMock));
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed(address token0) public notTestContracts(token0) {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Stable pool.
        aeroPoolMock.setStable(true);

        // Given : Token1 is added to the Registry, token0 is not.
        aeroPoolMock.setTokens(token0, address(mockERC20.token1));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.expectRevert(AerodromeVolatileAM.AssetNotAllowed.selector);
        aeroStableAM.addAsset(address(aeroPoolMock));
    }

    function testFuzz_Success_addAsset() public {
        // Given : Valid initial state
        setMockState();

        // When : An asset is added to the AM.
        aeroStableAM.addAsset(address(aeroPoolMock));

        // Then : It should return the correct values
        assertTrue(registryExtension.inRegistry(address(aeroPoolMock)));
        assertTrue(aeroStableAM.inAssetModule(address(aeroPoolMock)));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPoolMock)));

        bytes32[] memory underlyingAssetKeys = aeroStableAM.getUnderlyingAssets(assetKey);
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1))));

        (uint64 decimals0, uint64 decimals1) = aeroStableAM.underlyingAssetsDecimals(address(aeroPoolMock));
        assertEq(decimals0, 10 ** mockERC20.token1.decimals());
        assertEq(decimals1, 10 ** mockERC20.stable1.decimals());
    }
}
