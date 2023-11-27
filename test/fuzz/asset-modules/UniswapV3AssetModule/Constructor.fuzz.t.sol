/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AssetModule_Fuzz_Test } from "./_UniswapV3AssetModule.fuzz.t.sol";

import { UniswapV3AssetModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV3AssetModule".
 */
contract Constructor_UniswapV3AssetModule_Fuzz_Test is UniswapV3AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        UniswapV3AssetModuleExtension uniV3AssetModule_ =
            new UniswapV3AssetModuleExtension(registry_, address(nonfungiblePositionManager));
        vm.stopPrank();

        assertEq(uniV3AssetModule_.REGISTRY(), registry_);
        assertEq(uniV3AssetModule_.ASSET_TYPE(), 1);
        assertEq(uniV3AssetModule_.getNonFungiblePositionManager(), address(nonfungiblePositionManager));
        assertEq(uniV3AssetModule_.getUniswapV3Factory(), address(uniswapV3Factory));
    }
}
