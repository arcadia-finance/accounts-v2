/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { UniswapV2PairMalicious } from "../../../utils/mocks/UniswapV2PairMalicious.sol";
import { UniswapV2PairMock } from "../../.././utils/mocks/UniswapV2PairMock.sol";

/**
 * @notice Fuzz tests for the "addPool" of contract "UniswapV2PricingModule".
 */
contract AddPool_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addPool_NonPool(address token0, address token1) public {
        UniswapV2PairMalicious pool = new UniswapV2PairMalicious(token0, token1);

        vm.expectRevert("PMUV2_AA: Not a Pool");
        uniswapV2PricingModule.addPool(address(pool));
    }

    function testFuzz_Revert_addPool_Token0NotAllowed() public {
        vm.expectRevert("PMUV2_AA: Token0 not Allowed");
        uniswapV2PricingModule.addPool(address(pairToken1Token3));
    }

    function testFuzz_Revert_addPool_Token1NotAllowed() public {
        UniswapV2PairMock pairToken1Token4 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token1), address(mockERC20.token4)));

        vm.expectRevert("PMUV2_AA: Token1 not Allowed");
        uniswapV2PricingModule.addPool(address(pairToken1Token4));
    }

    function testFuzz_Revert_addPool_OverwriteExistingAsset() public {
        uniswapV2PricingModule.addPool(address(pairToken1Token2));

        vm.expectRevert("MR_AA: Asset already in mainreg");
        uniswapV2PricingModule.addPool(address(pairToken1Token2));
    }

    function testFuzz_Success_addPool(address caller) public {
        vm.prank(caller);
        uniswapV2PricingModule.addPool(address(pairToken1Token2));

        assertTrue(mainRegistryExtension.inMainRegistry(address(pairToken1Token2)));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pairToken1Token2)));
        bytes32[] memory underlyingAssetKeys = uniswapV2PricingModule.getUnderlyingAssets(assetKey);

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2))));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
    }
}
