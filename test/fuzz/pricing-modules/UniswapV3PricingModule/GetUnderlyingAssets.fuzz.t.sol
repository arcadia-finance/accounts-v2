/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "_getUnderlyingAssets" of contract "UniswapV3PricingModule".
 */
contract GetUnderlyingAssets_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint256 internal id;
    address token0;
    address token1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();

        id = addLiquidity(poolStable1Stable2, 100, 100, users.liquidityProvider, 0, 1, true);
        (token0, token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        deployUniswapV3PricingModule(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InPricingModule() public {
        vm.prank(users.creatorAddress);
        uniV3PricingModule.addAsset(id);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(id), address(nonfungiblePositionManagerMock)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), token0));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), token1));

        bytes32[] memory actualUnderlyingAssetKeys = uniV3PricingModule.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInPricingModule() public {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(id), address(nonfungiblePositionManagerMock)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), token0));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), token1));

        bytes32[] memory actualUnderlyingAssetKeys = uniV3PricingModule.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }
}
