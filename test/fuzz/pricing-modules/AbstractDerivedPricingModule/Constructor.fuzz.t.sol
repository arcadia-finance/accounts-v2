/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { DerivedPricingModuleMock } from "../../../utils/mocks/DerivedPricingModuleMock.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "AbstractDerivedPricingModule".
 */
contract Constructor_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_, uint256 assetType_, address riskManager_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        DerivedPricingModuleMock pricingModule_ = new DerivedPricingModuleMock(
            mainRegistry_,
            assetType_,
            riskManager_
        );
        vm.stopPrank();

        assertEq(pricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(pricingModule_.ASSET_TYPE(), assetType_);
        assertEq(pricingModule_.riskManager(), riskManager_);
        assertFalse(pricingModule_.getPrimaryFlag());
    }
}
