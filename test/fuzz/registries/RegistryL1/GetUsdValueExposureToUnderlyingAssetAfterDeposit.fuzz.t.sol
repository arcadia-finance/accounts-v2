/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "getUsdValueExposureToUnderlyingAssetAfterDeposit" of contract "RegistryL1".
 */
contract GetUsdValueExposureToUnderlyingAssetAfterDeposit_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getUsdValueExposureToUnderlyingAssetAfterDeposit_NonAssetModule(
        address unprivilegedAddress_,
        address underlyingAsset,
        uint96 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) public {
        vm.assume(!registry_.isAssetModule(unprivilegedAddress_));

        vm.prank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        registry_.getUsdValueExposureToUnderlyingAssetAfterDeposit(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    function testFuzz_Success_getUsdValueExposureToUnderlyingAssetAfterDeposit(
        address upperAssetModule,
        address underlyingAsset,
        uint96 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset,
        uint256 usdValue
    ) public {
        vm.assume(deltaExposureAssetToUnderlyingAsset <= type(int112).max); // MaxExposure.
        vm.assume(deltaExposureAssetToUnderlyingAsset > type(int256).min); // Overflows on inversion.

        registry_.setAssetModule(underlyingAsset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), underlyingAsset, underlyingAssetId, type(uint112).max, 100, 100
        );

        stdstore.target(address(registry_)).sig(registry_.isAssetModule.selector).with_key(address(upperAssetModule))
            .checked_write(true);

        // Prepare expected internal call.
        bytes memory data = abi.encodeCall(
            primaryAM.processIndirectDeposit,
            (
                address(creditorUsd),
                underlyingAsset,
                underlyingAssetId,
                exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        vm.prank(upperAssetModule);
        vm.expectCall(address(primaryAM), data);
        (, uint256 usdExposureAssetToUnderlyingAsset) = registry_.getUsdValueExposureToUnderlyingAssetAfterDeposit(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        assertEq(usdExposureAssetToUnderlyingAsset, usdValue);
    }
}
