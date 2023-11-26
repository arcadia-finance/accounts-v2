/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AssetModule_Fuzz_Test } from "./_UniswapV2AssetModule.fuzz.t.sol";

import { UniswapV2AssetModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV2AssetModule".
 */
contract Constructor_UniswapV2AssetModule_Fuzz_Test is UniswapV2AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        UniswapV2AssetModuleExtension uniswapV2AssetModule_ =
            new UniswapV2AssetModuleExtension(registry_, address(uniswapV2Factory));
        vm.stopPrank();
        assertEq(uniswapV2AssetModule_.REGISTRY(), registry_);
        assertEq(uniswapV2AssetModule_.ASSET_TYPE(), 0);
        assertEq(uniswapV2AssetModule_.getUniswapV2Factory(), address(uniswapV2Factory));
    }
}
