/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processDirectDeposit" of contract "AbstractPrimaryPricingModule".
 */
contract ProcessDirectDeposit_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_isAllowlisted_False(address asset, uint256 id) public view {
        bool isAllowListed = pricingModule.isAllowListed(asset, id);
        assert(isAllowListed == false);
    }

    function testFuzz_Success_isAllowlisted_True(address asset, uint256 id, uint128 exposure, uint128 maxExposure) public {
        vm.assume(maxExposure > 0);
        vm.assume(exposure < maxExposure);
        pricingModule.setExposure(asset, exposure, maxExposure);

        bool isAllowListed = pricingModule.isAllowListed(asset, id);
        assert(isAllowListed == true);
    }

}
