/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Metadex03PoolAM_Fuzz_Test } from "./_Metadex03PoolAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "Metadex03PoolAM".
 */
contract GetUnderlyingAssets_Metadex03PoolAM_Fuzz_Test is Metadex03PoolAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03PoolAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets_InAssetModule(bool stable, uint8 decimals0, uint8 decimals1) public {
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

        // And: A pool of the fuzzed type for that pair is added to the Asset Module.
        metadex03Pool = createPoolMetadex03(address(token0), address(token1), stable);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(metadex03Pool));
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(metadex03Pool)));

        // When: The underlying assets of the pool are queried.
        bytes32[] memory underlyingAssetKeys = metadex03PoolAM.getUnderlyingAssets(assetKey);

        // Then: Both pool tokens are returned, in the order of the pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(token0))));
        // forge-lint: disable-next-item(unsafe-typecast)
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(token1))));
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule(bytes32 assetKey) public view {
        // Given: No asset is added to the Asset Module.

        // When: The underlying assets of the key are queried.
        bytes32[] memory underlyingAssetKeys = metadex03PoolAM.getUnderlyingAssets(assetKey);

        // Then: No underlying asset keys are returned.
        assertEq(underlyingAssetKeys.length, 0);
    }
}
