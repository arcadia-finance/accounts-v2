/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectWithdrawal" of contract "AbstractDerivedPricingModule".
 */
contract ProcessDirectWithdrawal_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonMainRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint256 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        derivedPricingModule.processDirectWithdrawal(creditor, asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        int256 amount
    ) public {
        // And: No overflow on negation most negative int256 (this overflows).
        vm.assume(amount > type(int256).min);
        amount = amount >= 0 ? -amount : amount;

        // And: Withdrawal does not revert.
        (protocolState, assetState, underlyingPMState,, amount) =
            givenNonRevertingWithdrawal(protocolState, assetState, underlyingPMState, 0, amount);
        assert(amount <= 0);

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState, assetState.creditor);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // When: "MainRegistry" calls "processDirectWithdrawal".
        vm.prank(address(mainRegistryExtension));
        derivedPricingModule.processDirectWithdrawal(
            assetState.creditor, assetState.asset, assetState.assetId, uint256(-amount)
        );

        // Then: Transaction does not revert.
    }
}
