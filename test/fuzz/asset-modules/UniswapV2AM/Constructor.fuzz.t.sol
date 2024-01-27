/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

import { UniswapV2AMExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV2AM".
 */
contract Constructor_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        UniswapV2AMExtension uniswapV2AM_ = new UniswapV2AMExtension(registry_, address(uniswapV2Factory));
        vm.stopPrank();
        assertEq(uniswapV2AM_.REGISTRY(), registry_);
        assertEq(uniswapV2AM_.ASSET_TYPE(), 0);
        assertEq(uniswapV2AM_.getUniswapV2Factory(), address(uniswapV2Factory));
    }
}
