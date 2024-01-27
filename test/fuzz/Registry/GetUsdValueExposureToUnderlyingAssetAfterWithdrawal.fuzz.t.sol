/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" of contract "Registry".
 */
contract GetUsdValueExposureToUnderlyingAssetAfterWithdrawal_Registry_Fuzz_Test is Registry_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getUsdValueExposureToUnderlyingAssetAfterWithdrawal_NonAssetModule(
        address unprivilegedAddress_,
        address underlyingAsset,
        uint96 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) public {
        vm.assume(!registryExtension.isAssetModule(unprivilegedAddress_));

        vm.prank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        registryExtension.getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    function testFuzz_Success_getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
        address upperAssetModule,
        address underlyingAsset,
        uint96 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset,
        uint256 usdValue
    ) public {
        vm.assume(deltaExposureAssetToUnderlyingAsset <= type(int112).max); // MaxExposure.
        vm.assume(deltaExposureAssetToUnderlyingAsset > type(int256).min); // Overflows on inversion.

        registryExtension.setAssetToAssetModule(underlyingAsset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), underlyingAsset, underlyingAssetId, type(uint112).max, 100, 100
        );

        stdstore.target(address(registryExtension)).sig(registryExtension.isAssetModule.selector).with_key(
            address(upperAssetModule)
        ).checked_write(true);

        // Prepare expected internal call.
        bytes memory data = abi.encodeCall(
            primaryAM.processIndirectWithdrawal,
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
        uint256 usdExposureAssetToUnderlyingAsset = registryExtension
            .getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        assertEq(usdExposureAssetToUnderlyingAsset, usdValue);
    }
}
