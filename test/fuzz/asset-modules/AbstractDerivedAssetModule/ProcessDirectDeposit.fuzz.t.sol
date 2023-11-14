/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedAssetModule_Fuzz_Test } from "./_AbstractDerivedAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "AbstractDerivedAssetModule".
 */
contract ProcessDirectDeposit_AbstractDerivedAssetModule_Fuzz_Test is AbstractDerivedAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint256 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_MAIN_REGISTRY");
        derivedAssetModule.processDirectDeposit(creditor, asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(
        DerivedAssetModuleProtocolState memory protocolState,
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
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
        setDerivedAssetModuleProtocolState(protocolState, assetState.creditor);
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "MainRegistry" calls "processDirectDeposit".
        vm.prank(address(mainRegistryExtension));
        derivedAssetModule.processDirectDeposit(
            assetState.creditor, assetState.asset, assetState.assetId, uint256(amount)
        );

        // Then: Transaction does not revert.
    }
}