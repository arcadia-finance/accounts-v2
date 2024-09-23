/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";
import { UniswapV4AMExtension } from "../../../utils/extensions/UniswapV4AMExtension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV4AM".
 */
contract Constructor_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.owner);
        UniswapV4AMExtension uniV4AssetModule_ =
            new UniswapV4AMExtension(registry_, address(positionManager), address(stateView));
        vm.stopPrank();

        assertEq(uniV4AssetModule_.REGISTRY(), registry_);
        assertEq(uniV4AssetModule_.ASSET_TYPE(), 2);
        assertEq(uniV4AssetModule_.getPositionManager(), address(positionManager));
        assertEq(uniV4AssetModule_.getUniswapV4StateView(), address(stateView));
    }
}
