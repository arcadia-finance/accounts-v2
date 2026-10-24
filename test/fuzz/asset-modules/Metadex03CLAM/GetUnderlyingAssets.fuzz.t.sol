/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetUnderlyingAssets_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    address token0;
    address token1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        (token0, token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        deployMetadex03CLAM(address(metadex03PositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InAssetModule(uint128 liquidity, int24 tickLower, int24 tickUpper)
        public
    {
        // Given: A valid liquidity position in the stable1/stable2 pool.
        tickLower = int24(bound(tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        tickUpper = int24(bound(tickUpper, tickLower + 1, TickMath.MAX_TICK));
        liquidity = uint128(bound(liquidity, 1, poolStable1Stable2.maxLiquidityPerTick()));
        (uint256 assetId,,) = addLiquidityMetadex03CL(
            poolStable1Stable2, liquidity, users.liquidityProvider, tickLower, tickUpper, false
        );

        // And: The position is added to the Asset Module.
        metadex03CLAM.addAsset(assetId);

        // When: The underlying assets of the position are queried.
        bytes32[] memory actualUnderlyingAssetKeys = metadex03CLAM.getUnderlyingAssets(
            bytes32(abi.encodePacked(uint96(assetId), address(metadex03PositionManager)))
        );

        // Then: The stored keys of both pool tokens are returned.
        assertEq(actualUnderlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), token0)));
        assertEq(actualUnderlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), token1)));
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule(uint128 liquidity, int24 tickLower, int24 tickUpper)
        public
    {
        // Given: A valid liquidity position in the stable1/stable2 pool, not added to the Asset Module.
        tickLower = int24(bound(tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        tickUpper = int24(bound(tickUpper, tickLower + 1, TickMath.MAX_TICK));
        liquidity = uint128(bound(liquidity, 1, poolStable1Stable2.maxLiquidityPerTick()));
        (uint256 assetId,,) = addLiquidityMetadex03CL(
            poolStable1Stable2, liquidity, users.liquidityProvider, tickLower, tickUpper, false
        );

        // When: The underlying assets of the position are queried.
        bytes32[] memory actualUnderlyingAssetKeys = metadex03CLAM.getUnderlyingAssets(
            bytes32(abi.encodePacked(uint96(assetId), address(metadex03PositionManager)))
        );

        // Then: The keys of both pool tokens are read from the position manager.
        assertEq(actualUnderlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), token0)));
        assertEq(actualUnderlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), token1)));
    }
}
