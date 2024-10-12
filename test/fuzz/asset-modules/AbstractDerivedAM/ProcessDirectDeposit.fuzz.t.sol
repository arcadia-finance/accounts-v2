/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AbstractDerivedAM_Fuzz_Test, AssetModule } from "./_AbstractDerivedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "AbstractDerivedAM".
 */
contract ProcessDirectDeposit_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint256 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(registry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        derivedAM.processDirectDeposit(creditor, asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
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
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "Registry" calls "processDirectDeposit".
        vm.prank(address(registry));
        uint256 recursiveCalls =
            derivedAM.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, uint256(amount));

        assertEq(recursiveCalls, 2);
    }
}
