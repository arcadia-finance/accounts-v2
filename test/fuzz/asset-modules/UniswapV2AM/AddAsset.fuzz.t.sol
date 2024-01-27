/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test, UniswapV2AM } from "./_UniswapV2AM.fuzz.t.sol";

import { UniswapV2PairMalicious } from "../../../utils/mocks/UniswapV2/UniswapV2PairMalicious.sol";
import { UniswapV2PairMock } from "../../../utils/mocks/UniswapV2/UniswapV2PairMock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "UniswapV2AM".
 */
contract AddAsset_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonPool(address token0, address token1) public {
        UniswapV2PairMalicious pool = new UniswapV2PairMalicious(token0, token1);

        vm.expectRevert(UniswapV2AM.Not_A_Pool.selector);
        uniswapV2AM.addAsset(address(pool));
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed() public {
        vm.expectRevert(UniswapV2AM.Token0_Not_Allowed.selector);
        uniswapV2AM.addAsset(address(pairToken1Token3));
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed() public {
        UniswapV2PairMock pairToken1Token4 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token1), address(mockERC20.token4)));

        vm.expectRevert(UniswapV2AM.Token1_Not_Allowed.selector);
        uniswapV2AM.addAsset(address(pairToken1Token4));
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        uniswapV2AM.addAsset(address(pairToken1Token2));

        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        uniswapV2AM.addAsset(address(pairToken1Token2));
    }

    function testFuzz_Success_addAsset(address caller) public {
        vm.prank(caller);
        uniswapV2AM.addAsset(address(pairToken1Token2));

        assertTrue(registryExtension.inRegistry(address(pairToken1Token2)));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pairToken1Token2)));
        bytes32[] memory underlyingAssetKeys = uniswapV2AM.getUnderlyingAssets(assetKey);

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
    }
}
