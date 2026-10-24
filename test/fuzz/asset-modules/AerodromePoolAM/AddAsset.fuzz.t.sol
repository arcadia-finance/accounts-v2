/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { AerodromePoolAM_Fuzz_Test } from "./_AerodromePoolAM.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";

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
    function testFuzz_Revert_addAsset_NotOwner(address sender, address asset) public {
        // Given: The sender is not the owner.
        vm.assume(sender != users.owner);

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert("UNAUTHORIZED");
        aeroPoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_InvalidPool(address asset) public {
        // Given: The asset is not a pool in the Aerodrome Factory.
        vm.assume(asset != address(aeroPool));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.InvalidPool.selector);
        aeroPoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed(bool isStable, address token0) public canReceiveERC721(token0) {
        // Given: A pool of the fuzzed type whose token0 is not in the Registry and whose token1 is.
        aeroPoolFactory.setPool(address(aeroPool));
        aeroPool.setStable(isStable);
        aeroPool.setTokens(token0, address(mockERC20.token1));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        aeroPoolAM.addAsset(address(aeroPool));
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed(bool isStable, address token1) public canReceiveERC721(token1) {
        // Given: A pool of the fuzzed type whose token1 is not in the Registry and whose token0 is.
        aeroPoolFactory.setPool(address(aeroPool));
        aeroPool.setStable(isStable);
        aeroPool.setTokens(address(mockERC20.token1), token1);

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        aeroPoolAM.addAsset(address(aeroPool));
    }

    function testFuzz_Success_addAsset_VolatilePool(uint8 decimals0, uint8 decimals1) public {
        // Given: Two allowed tokens.
        // forge-lint: disable-next-item(unsafe-typecast)
        decimals0 = uint8(bound(decimals0, 0, 18));
        // forge-lint: disable-next-item(unsafe-typecast)
        decimals1 = uint8(bound(decimals1, 0, 18));
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKA", decimals0);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKB", decimals1);
        (ERC20Mock token0, ERC20Mock token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        addAssetToArcadia(address(token0), 1e18);
        addAssetToArcadia(address(token1), 1e18);

        // And: The pool holds that pair and is volatile.
        aeroPool.setTokens(address(token0), address(token1));
        aeroPool.setStable(false);

        // When: An asset is added to the AM.
        vm.prank(users.owner);
        aeroPoolAM.addAsset(address(aeroPool));

        // Then: The pool is in the Registry and in the Asset Module.
        assertTrue(registry.inRegistry(address(aeroPool)));
        assertTrue(aeroPoolAM.inAssetModule(address(aeroPool)));

        // And: Both pool tokens are its underlying assets.
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPool)));
        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));

        // And: The stored information is empty.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) = aeroPoolAM.assetToInformation(address(aeroPool));
        assertFalse(stable);
        assertEq(unitCorrection0, 0);
        assertEq(unitCorrection1, 0);
    }

    function testFuzz_Success_addAsset_StablePool(uint8 decimals0, uint8 decimals1) public {
        // Given: Two allowed tokens.
        // forge-lint: disable-next-item(unsafe-typecast)
        decimals0 = uint8(bound(decimals0, 0, 18));
        // forge-lint: disable-next-item(unsafe-typecast)
        decimals1 = uint8(bound(decimals1, 0, 18));
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKA", decimals0);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKB", decimals1);
        (ERC20Mock token0, ERC20Mock token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        addAssetToArcadia(address(token0), 1e18);
        addAssetToArcadia(address(token1), 1e18);

        // And: The pool holds that pair and is stable.
        aeroPool.setTokens(address(token0), address(token1));
        aeroPool.setStable(true);

        // When: An asset is added to the AM.
        vm.prank(users.owner);
        aeroPoolAM.addAsset(address(aeroPool));

        // Then: The pool is in the Registry and in the Asset Module.
        assertTrue(registry.inRegistry(address(aeroPool)));
        assertTrue(aeroPoolAM.inAssetModule(address(aeroPool)));

        // And: Both pool tokens are its underlying assets.
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(aeroPool)));
        bytes32[] memory underlyingAssetKeys = aeroPoolAM.getUnderlyingAssets(assetKey);
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));

        // And: The unit corrections normalise both tokens to 18 decimals.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) = aeroPoolAM.assetToInformation(address(aeroPool));
        assertTrue(stable);
        assertEq(unitCorrection0, 10 ** (18 - token0.decimals()));
        assertEq(unitCorrection1, 10 ** (18 - token1.decimals()));
    }
}
