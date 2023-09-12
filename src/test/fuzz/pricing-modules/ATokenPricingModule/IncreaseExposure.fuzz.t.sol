/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ATokenPricingModule_Fuzz_Test, Constants } from "./ATokenPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "increaseExposure" of contract "ATokenPricingModule".
 */
contract IncreaseExposure_ATokenPricingModule_Fuzz_Test is ATokenPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ATokenPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
}
