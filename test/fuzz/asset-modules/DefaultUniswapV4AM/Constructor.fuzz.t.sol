/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { DefaultUniswapV4AMExtension } from "../../../utils/extensions/DefaultUniswapV4AMExtension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "DefaultUniswapV4AM".
 */
contract Constructor_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.owner);
        DefaultUniswapV4AMExtension uniV4AssetModule_ =
            new DefaultUniswapV4AMExtension(registry_, address(positionManagerV4));
        vm.stopPrank();

        assertEq(uniV4AssetModule_.REGISTRY(), registry_);
        assertEq(uniV4AssetModule_.ASSET_TYPE(), 2);
        assertEq(uniV4AssetModule_.getPositionManager(), address(positionManagerV4));
        assertEq(uniV4AssetModule_.getUniswapV4PoolManager(), address(poolManager));
    }
}
