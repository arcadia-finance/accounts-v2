/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { UniswapV3WithFeesPricingModule } from
    "../../../../src/pricing-modules/UniswapV3/UniswapV3WithFeesPricingModule.sol";

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
    function testFuzz_Success_deployment(address mainRegistry_, address oracleHub_, address riskManager_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        UniswapV3WithFeesPricingModule uniV3PricingModule_ = new UniswapV3WithFeesPricingModule(
            mainRegistry_,
            oracleHub_,
            riskManager_,
            address(nonfungiblePositionManager)
        );
        vm.stopPrank();

        assertEq(uniV3PricingModule_.mainRegistry(), mainRegistry_);
        assertEq(uniV3PricingModule_.oracleHub(), oracleHub_);
        assertEq(uniV3PricingModule_.assetType(), 1);
        assertEq(uniV3PricingModule_.riskManager(), riskManager_);
    }
}
