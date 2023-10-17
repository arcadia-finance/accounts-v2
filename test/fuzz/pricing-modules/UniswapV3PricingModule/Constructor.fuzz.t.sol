/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { UniswapV3PricingModule } from "../../../../src/pricing-modules/UniswapV3/UniswapV3PricingModule.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "UniswapV3PricingModule".
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
    function testFuzz_Success_deployment(address mainRegistry_, address riskManager_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        UniswapV3PricingModule uniV3PricingModule_ = new UniswapV3PricingModule(
            mainRegistry_,
            riskManager_,
            address(nonfungiblePositionManager)
        );
        vm.stopPrank();

        assertEq(uniV3PricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(uniV3PricingModule_.ASSET_TYPE(), 1);
        assertEq(uniV3PricingModule_.riskManager(), riskManager_);
    }
}
