/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { DerivedPricingModuleMock } from "../../../utils/mocks/DerivedPricingModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractDerivedPricingModule".
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
    function testFuzz_Success_deployment(address mainRegistry_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        DerivedPricingModuleMock pricingModule_ = new DerivedPricingModuleMock(
            mainRegistry_,
            assetType_
        );
        vm.stopPrank();

        assertEq(pricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(pricingModule_.ASSET_TYPE(), assetType_);
        assertFalse(pricingModule_.getPrimaryFlag());
    }
}
