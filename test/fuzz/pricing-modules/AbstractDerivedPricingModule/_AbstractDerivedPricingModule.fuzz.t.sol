/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";
import {
    AbstractDerivedPricingModuleExtension,
    AbstractPrimaryPricingModuleExtension,
    MainRegistryExtension_New
} from "../../../utils/Extensions.sol";
import { AbstractPrimaryPricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "DerivedPricingModule" fuzz tests.
 */
abstract contract AbstractDerivedPricingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AbstractDerivedPricingModuleExtension internal derivedPricingModule;
    AbstractPrimaryPricingModuleExtension internal primaryPricingModule;
    MainRegistryExtension_New internal mainRegistryExtension_New;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        mainRegistryExtension_New = new MainRegistryExtension_New(address(factory));

        derivedPricingModule =
        new AbstractDerivedPricingModuleExtension(address(mainRegistryExtension_New), address(oracleHub), 0, users.creatorAddress);

        primaryPricingModule =
        new AbstractPrimaryPricingModuleExtension(address(mainRegistryExtension_New), address(oracleHub), 0, users.creatorAddress);

        mainRegistryExtension_New.addPricingModule(address(derivedPricingModule));
        mainRegistryExtension_New.addPricingModule(address(primaryPricingModule));

        // We assume conversion rate and price of underlying asset both equal to 1.
        // Conversion rate and prices of underlying assets will be tested in specific pricing modules.
        derivedPricingModule.setConversionRate(1e18);

        vm.stopPrank();
    }
}
