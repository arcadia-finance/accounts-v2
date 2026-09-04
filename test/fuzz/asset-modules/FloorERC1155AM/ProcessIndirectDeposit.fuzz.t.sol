/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { FloorERC1155AM } from "../../../utils/mocks/asset-modules/FloorERC1155AM.sol";
import { FloorERC1155AM_Fuzz_Test } from "./_FloorERC1155AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "FloorERC1155AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ProcessIndirectDeposit_FloorERC1155AM_Fuzz_Test is FloorERC1155AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonRegistry(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        address unprivilegedAddress_
    ) public {
        vm.assume(unprivilegedAddress_ != address(registry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        floorERC1155AM.processIndirectDeposit(
            address(creditorUsd), asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_WrongId(
        address asset,
        uint96 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        assetId = uint96(bound(assetId, 1, type(uint96).max));
        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);

        vm.startPrank(address(registry));
        vm.expectRevert(FloorERC1155AM.AssetNotAllowed.selector);
        floorERC1155AM.processIndirectDeposit(
            address(creditorUsd), asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_positiveDelta(
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint112 maxExposure
    ) public {
        deltaExposureUpperAssetToAsset = bound(
            deltaExposureUpperAssetToAsset, 1, int256(uint256(type(uint112).max)) - 1
        );
        maxExposure = uint112(bound(maxExposure, uint256(deltaExposureUpperAssetToAsset) + 1, type(uint112).max));
        // To avoid overflow when calculating "usdExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint112).max - 1);

        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC1155.sft2), 0, maxExposure, 0, 0);

        (uint256 actualValueInUsd,,) = floorERC1155AM.getValue(address(creditorUsd), address(mockERC1155.sft2), 0, 1);

        exposureUpperAssetToAsset = bound(
            exposureUpperAssetToAsset,
            0,
            actualValueInUsd == 0 ? type(uint256).max : type(uint256).max / actualValueInUsd
        );

        vm.prank(address(registry));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = floorERC1155AM.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC1155.sft2),
            0,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(recursiveCalls, 1);
        assertEq(usdExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC1155.sft2)));
        (uint128 actualExposure,,,) = floorERC1155AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, uint256(deltaExposureUpperAssetToAsset));
    }

    function testFuzz_Success_processIndirectDeposit_negativeDelta_NoUnderflow(
        uint256 exposureUpperAssetToAsset,
        uint256 initialExposure,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        initialExposure = bound(initialExposure, 1, type(uint112).max - 1);
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 1, initialExposure);

        // To avoid overflow when calculating "usdExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint112).max);

        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 0, type(uint112).max, 0, 0
        );

        vm.prank(address(registry));
        floorERC1155AM.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 0, initialExposure);

        (uint256 actualValueInUsd,,) = floorERC1155AM.getValue(address(creditorUsd), address(mockERC1155.sft2), 0, 1);

        exposureUpperAssetToAsset = bound(
            exposureUpperAssetToAsset,
            0,
            actualValueInUsd == 0 ? type(uint256).max : type(uint256).max / actualValueInUsd
        );

        vm.prank(address(registry));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = floorERC1155AM.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC1155.sft2),
            0,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(recursiveCalls, 1);
        assertEq(usdExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC1155.sft2)));
        (uint128 actualExposure,,,) = floorERC1155AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, initialExposure - deltaExposureUpperAssetToAsset);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDelta_Underflow(
        uint256 exposureUpperAssetToAsset,
        uint256 initialExposure,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        initialExposure = bound(initialExposure, 1, type(uint112).max - 1);
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, initialExposure + 1, uint256(type(int256).max));

        // To avoid overflow when calculating "usdExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint112).max);

        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 0, type(uint112).max, 0, 0
        );

        vm.prank(address(registry));
        floorERC1155AM.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 0, initialExposure);

        (uint256 actualValueInUsd,,) = floorERC1155AM.getValue(address(creditorUsd), address(mockERC1155.sft2), 0, 1);

        exposureUpperAssetToAsset = bound(
            exposureUpperAssetToAsset,
            0,
            actualValueInUsd == 0 ? type(uint256).max : type(uint256).max / actualValueInUsd
        );

        vm.prank(address(registry));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = floorERC1155AM.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC1155.sft2),
            0,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(recursiveCalls, 1);
        assertEq(usdExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        // And: Exposure is set to zero instead of underflowing.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC1155.sft2)));
        (uint128 actualExposure,,,) = floorERC1155AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }
}
