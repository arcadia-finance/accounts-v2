/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { PrimaryPricingModuleMock } from "../../../utils/mocks/PrimaryPricingModuleMock.sol";

/**
 * @notice Common logic needed by all "AbstractPrimaryPricingModule" fuzz tests.
 */
abstract contract AbstractPrimaryPricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    PrimaryPricingModuleMock internal pricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        pricingModule =
            new PrimaryPricingModuleMock(address(mainRegistryExtension), address(oracleHub), 0, users.creatorAddress);
    }
}
