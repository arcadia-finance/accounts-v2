/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { UniswapV3PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "UniswapV3PricingModule".
 */
contract Constructor_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_) public {
        vm.startPrank(users.creatorAddress);
        UniswapV3PricingModuleExtension uniV3PricingModule_ = new UniswapV3PricingModuleExtension(
            mainRegistry_,
            address(nonfungiblePositionManager)
        );
        vm.stopPrank();

        assertEq(uniV3PricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(uniV3PricingModule_.ASSET_TYPE(), 1);
        assertFalse(uniV3PricingModule_.getPrimaryFlag());
        assertEq(uniV3PricingModule_.getNonFungiblePositionManager(), address(nonfungiblePositionManager));
        assertEq(uniV3PricingModule_.getUniswapV3Factory(), address(uniswapV3Factory));
    }
}
