/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromePoolAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { Metadex03PoolAM } from "../../../../src/asset-modules/Metadex03/Metadex03PoolAM.sol";
import { Metadex03PoolAM_Fuzz_Test } from "./_Metadex03PoolAM.fuzz.t.sol";
import { Metadex03PoolMock } from "../../../utils/mocks/Metadex03/Metadex03PoolMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "Metadex03PoolAM".
 */
contract AddAsset_Metadex03PoolAM_Fuzz_Test is Metadex03PoolAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03PoolAM_Fuzz_Test.setUp();
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
        metadex03PoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_InvalidPool(address asset) public {
        // Given: The asset is a pool in neither the stable nor the volatile factory.
        vm.assume(asset != address(metadex03Pool));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.InvalidPool.selector);
        metadex03PoolAM.addAsset(asset);
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed(bool stable, uint8 decimals) public {
        // Given: A pool of the fuzzed type whose token0 is not in the Registry and whose token1 is.
        // forge-lint: disable-next-item(unsafe-typecast)
        decimals = uint8(bound(decimals, 0, 18));
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", decimals);
        while (address(token0) > address(mockERC20.token1)) {
            token0 = new ERC20Mock("Token 0", "TOK0", decimals);
        }
        IMetadex03V2Pool pool = createPoolMetadex03(address(token0), address(mockERC20.token1), stable);

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        metadex03PoolAM.addAsset(address(pool));
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed(bool stable, uint8 decimals) public {
        // Given: A pool of the fuzzed type whose token1 is not in the Registry and whose token0 is.
        // forge-lint: disable-next-item(unsafe-typecast)
        decimals = uint8(bound(decimals, 0, 18));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", decimals);
        while (address(token1) < address(mockERC20.token1)) {
            token1 = new ERC20Mock("Token 1", "TOK1", decimals);
        }
        IMetadex03V2Pool pool = createPoolMetadex03(address(mockERC20.token1), address(token1), stable);

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(AerodromePoolAM.AssetNotAllowed.selector);
        metadex03PoolAM.addAsset(address(pool));
    }

    function testFuzz_Revert_addAsset_InvalidPoolType(bytes32 poolType) public {
        // Given: A pool with an unknown POOL_TYPE, holding two allowed tokens.
        vm.assume(poolType != "V2_STABLE" && poolType != "V2_VOLATILE");
        Metadex03PoolMock pool = new Metadex03PoolMock();
        pool.setPoolType(poolType);
        pool.setTokens(address(mockERC20.token1), address(mockERC20.stable1));

        // And: The pool is registered in the volatile factory.
        stdstore.target(address(volatilePoolFactory))
            .sig(volatilePoolFactory.isPool.selector)
            .with_key(address(pool))
            .checked_write(true);

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(Metadex03PoolAM.InvalidPoolType.selector);
        metadex03PoolAM.addAsset(address(pool));
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

        // And: A volatile pool of that pair, created by the volatile factory.
        IMetadex03V2Pool volatilePool = createPoolMetadex03(address(token0), address(token1), false);

        // When: An asset is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(volatilePool));

        // Then: The pool is in the Registry and in the Asset Module.
        assertTrue(registry.inRegistry(address(volatilePool)));
        assertTrue(metadex03PoolAM.inAssetModule(address(volatilePool)));

        // And: Both pool tokens are its underlying assets.
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(volatilePool)));
        bytes32[] memory underlyingAssetKeys = metadex03PoolAM.getUnderlyingAssets(assetKey);
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));

        // And: The stored information is empty.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) =
            metadex03PoolAM.assetToInformation(address(volatilePool));
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

        // And: A stable pool of that pair, created by the stable factory.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(token0), address(token1), true);

        // When: An asset is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));

        // Then: The pool is in the Registry and in the Asset Module.
        assertTrue(registry.inRegistry(address(stablePool)));
        assertTrue(metadex03PoolAM.inAssetModule(address(stablePool)));

        // And: Both pool tokens are its underlying assets.
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(stablePool)));
        bytes32[] memory underlyingAssetKeys = metadex03PoolAM.getUnderlyingAssets(assetKey);
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));

        // And: The unit corrections normalise both tokens to 18 decimals.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) =
            metadex03PoolAM.assetToInformation(address(stablePool));
        assertTrue(stable);
        assertEq(unitCorrection0, 10 ** (18 - token0.decimals()));
        assertEq(unitCorrection1, 10 ** (18 - token1.decimals()));
    }

    function testFuzz_Success_addAsset_StablePool_FuzzedDecimals(uint8 decimals0, uint8 decimals1) public {
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

        // And: A stable pool of that pair.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(token0), address(token1), true);

        // When: An asset is added to the AM.
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));

        // Then: The unit corrections normalise both tokens to 18 decimals.
        (bool stable, uint64 unitCorrection0, uint64 unitCorrection1) =
            metadex03PoolAM.assetToInformation(address(stablePool));
        assertTrue(stable);
        assertEq(unitCorrection0, 10 ** (18 - token0.decimals()));
        assertEq(unitCorrection1, 10 ** (18 - token1.decimals()));
    }

    function testFuzz_Success_addAsset_SamePairInBothFactories(uint8 decimals0, uint8 decimals1) public {
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

        // And: That pair has a pool in the volatile AND in the stable factory.
        IMetadex03V2Pool volatilePool = createPoolMetadex03(address(token0), address(token1), false);
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(token0), address(token1), true);
        assertTrue(address(volatilePool) != address(stablePool));

        // When: Both pools are added to the AM.
        vm.startPrank(users.owner);
        metadex03PoolAM.addAsset(address(volatilePool));
        metadex03PoolAM.addAsset(address(stablePool));
        vm.stopPrank();

        // Then: Both pools are two distinct assets of the AM.
        assertTrue(registry.inRegistry(address(volatilePool)));
        assertTrue(registry.inRegistry(address(stablePool)));
        assertTrue(metadex03PoolAM.inAssetModule(address(volatilePool)));
        assertTrue(metadex03PoolAM.inAssetModule(address(stablePool)));

        // And: Only the stable pool stores the stable flag.
        (bool stableVolatilePool,,) = metadex03PoolAM.assetToInformation(address(volatilePool));
        (bool stableStablePool,,) = metadex03PoolAM.assetToInformation(address(stablePool));
        assertFalse(stableVolatilePool);
        assertTrue(stableStablePool);
    }
}
