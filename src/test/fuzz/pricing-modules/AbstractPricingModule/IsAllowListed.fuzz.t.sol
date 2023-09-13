/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./AbstractPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "isAllowListed" of contract "AbstractPricingModule".
 */
contract IsAllowListed_AbstractPricingModule_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_isAllowListed_Positive(address asset, uint128 maxExposure) public {
        // Given: asset is white listed
        vm.assume(maxExposure > 0);
        pricingModule.setExposure(asset, 0, maxExposure);

        // When: isAllowListed(asset, 0) is called
        // Then: It should return true
        assertTrue(pricingModule.isAllowListed(asset, 0));
    }

    function testSuccess_isAllowListed_Negative(address asset) public {
        // Given: All necessary contracts deployed on setup
        // And: asset is non whitelisted

        // When: isWhiteListed(asset, 0) is called
        // Then: It should return false
        assertTrue(!pricingModule.isAllowListed(asset, 0));
    }
}
