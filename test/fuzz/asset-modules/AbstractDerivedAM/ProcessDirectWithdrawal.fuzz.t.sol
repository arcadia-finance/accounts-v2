/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAM_Fuzz_Test, AssetModule } from "./_AbstractDerivedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectWithdrawal" of contract "AbstractDerivedAM".
 */
contract ProcessDirectWithdrawal_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint256 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        derivedAM.processDirectWithdrawal(creditor, asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
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
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "Registry" calls "processDirectWithdrawal".
        vm.prank(address(registryExtension));
        uint256 assetType = derivedAM.processDirectWithdrawal(
            assetState.creditor, assetState.asset, assetState.assetId, uint256(-amount)
        );

        assertEq(assetType, 0);
    }
}
