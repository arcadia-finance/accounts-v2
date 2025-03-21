/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { PrimaryAMMock } from "../../../utils/mocks/asset-modules/PrimaryAMMock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" of contract "UniswapV4HooksRegistry".
 */
contract GetUsdValueExposureToUnderlyingAssetAfterWithdrawal_UniswapV4HooksRegistry_Fuzz_Test is
    UniswapV4HooksRegistry_Fuzz_Test
{
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    PrimaryAMMock internal primaryAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        primaryAM = new PrimaryAMMock(address(registry), 0);
        registry.addAssetModule(address(primaryAM));
        vm.stopPrank();
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
        vm.assume(!v4HooksRegistry.isAssetModule(unprivilegedAddress_));

        vm.prank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        v4HooksRegistry.getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
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

        registry.setAssetModule(underlyingAsset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), underlyingAsset, underlyingAssetId, type(uint112).max, 100, 100
        );

        stdstore.target(address(v4HooksRegistry)).sig(registry.isAssetModule.selector).with_key(
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
        uint256 usdExposureAssetToUnderlyingAsset = v4HooksRegistry.getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
            address(creditorUsd),
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        assertEq(usdExposureAssetToUnderlyingAsset, usdValue);
    }
}
