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
// forge-lint: disable-next-item(unsafe-typecast)
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
        uint64 assetUnit,
        uint256 usdValue
    ) public {
        // MaxExposure, and no overflow on inversion.
        deltaExposureAssetToUnderlyingAsset =
            bound(deltaExposureAssetToUnderlyingAsset, type(int256).min + 1, type(int112).max);

        registry_.setAssetModule(underlyingAsset, address(primaryAM));

        // And: The asset price does not overflow.
        assetUnit = uint64(bound(assetUnit, 1, type(uint64).max));
        usdValue = bound(usdValue, 0, type(uint256).max / 1e18);
        exposureAssetToUnderlyingAsset = bound(
            exposureAssetToUnderlyingAsset, 0, usdValue == 0 ? type(uint256).max : type(uint256).max / usdValue
        );
        setPrimaryAMOracle(underlyingAsset, underlyingAssetId, assetUnit, usdValue);

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), underlyingAsset, underlyingAssetId, type(uint112).max, 100, 100
        );

        stdstore.target(address(registry_))
            .sig(registry_.isAssetModule.selector)
            .with_key(address(upperAssetModule))
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

        assertEq(usdExposureAssetToUnderlyingAsset, exposureAssetToUnderlyingAsset * usdValue / assetUnit);
    }
}
