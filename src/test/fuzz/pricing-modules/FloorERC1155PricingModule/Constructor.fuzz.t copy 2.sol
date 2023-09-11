/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC1155PricingModule_Fuzz_Test } from "./FloorERC1155PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "FloorERC1155PricingModule".
 */
contract Constructor_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
}
