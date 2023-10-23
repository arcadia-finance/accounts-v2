/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { PricingModuleMock } from "../../../utils/mocks/PricingModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractPricingModule".
 */
contract Constructor_AbstractPricingModule_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_, address riskManager_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        PricingModuleMock pricingModule_ = new PricingModuleMock(
            mainRegistry_,
            assetType_,
            riskManager_
        );
        vm.stopPrank();

        assertEq(pricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(pricingModule_.ASSET_TYPE(), assetType_);
        assertEq(pricingModule_.riskManager(), riskManager_);
    }
}
