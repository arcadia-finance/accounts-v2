/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getUsdValueExposureToUnderlyingAssetAfterDeposit" of contract "UniswapV4HooksRegistry".
 */
contract GetUsdValueExposureToUnderlyingAssetAfterDeposit_UniswapV4HooksRegistry_Fuzz_Test is
    UniswapV4HooksRegistry_Fuzz_Test
{
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-line(mixed-case-variable)
    PrimaryAMMock internal primaryAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        primaryAM = new PrimaryAMMock(users.owner, address(registry), 0);
        registry.addAssetModule(address(primaryAM));
        vm.stopPrank();
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
        vm.assume(!v4HooksRegistry.isAssetModule(unprivilegedAddress_));

        vm.prank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        v4HooksRegistry.getUsdValueExposureToUnderlyingAssetAfterDeposit(
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

        registry.setAssetModule(underlyingAsset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), underlyingAsset, underlyingAssetId, type(uint112).max, 100, 100
        );

        stdstore.target(address(v4HooksRegistry)).sig(registry.isAssetModule.selector)
            .with_key(address(upperAssetModule)).checked_write(true);

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
        (, uint256 usdExposureAssetToUnderlyingAsset) = v4HooksRegistry.getUsdValueExposureToUnderlyingAssetAfterDeposit(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        assertEq(usdExposureAssetToUnderlyingAsset, usdValue);
    }
}
