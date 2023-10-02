/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "processDirectDeposit" of contract "AbstractDerivedPricingModule".
 * @notice Tests performed here will validate the recursion flow of derived pricing modules.
 * Testing for conversion rates and getValue() will be done in pricing modules testing separately.
 */
contract ProcessDirectDeposit_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint256 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension_New));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        derivedPricingModule.processDirectDeposit(asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        int256 amount
    ) public {
        // And: No overflow on negation most negative int256 (this overflows).
        vm.assume(amount > type(int256).min);
        amount = amount >= 0 ? amount : -amount;

        // And: Deposit does not revert.
        (protocolState, assetState, underlyingPMState,, amount) =
            givenNonRevertingDeposit(protocolState, assetState, underlyingPMState, 0, amount);
        assert(amount >= 0);

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processDirectDeposit".
        vm.prank(address(mainRegistryExtension_New));
        derivedPricingModule.processDirectDeposit(assetState.asset, id, uint256(amount));

        // Then: Transaction does not revert.
    }
}