/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "FloorERC1155PricingModule".
 */
contract ProcessIndirectDeposit_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonMainRegistry(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        address unprivilegedAddress_
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC1155PricingModule.processIndirectDeposit(
            address(creditorUsd), asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_WrongId(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 0, oracleSft2ToUsdArr);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM1155_PID: ID not allowed");
        floorERC1155PricingModule.processIndirectDeposit(
            address(creditorUsd), asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }
}
