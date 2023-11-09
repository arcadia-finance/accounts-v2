/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { UniswapV2PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV2PricingModule".
 */
contract Constructor_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_) public {
        vm.startPrank(users.creatorAddress);
        UniswapV2PricingModuleExtension uniswapV2PricingModule_ = new UniswapV2PricingModuleExtension(
            mainRegistry_,
            address(uniswapV2Factory)
        );
        vm.stopPrank();
        assertEq(uniswapV2PricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(uniswapV2PricingModule_.ASSET_TYPE(), 0);
        assertFalse(uniswapV2PricingModule_.getPrimaryFlag());
        assertEq(uniswapV2PricingModule_.getUniswapV2Factory(), address(uniswapV2Factory));
    }
}
