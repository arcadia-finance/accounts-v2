/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155AssetModule_Fuzz_Test } from "./_FloorERC1155AssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "FloorERC1155AssetModule".
 */
contract ProcessIndirectDeposit_FloorERC1155AssetModule_Fuzz_Test is FloorERC1155AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155AssetModule_Fuzz_Test.setUp();
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
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_REGISTRY");
        floorERC1155AssetModule.processIndirectDeposit(
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
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(users.creatorAddress);
        floorERC1155AssetModule.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);

        vm.startPrank(address(registryExtension));
        vm.expectRevert("AM1155_PID: Asset not allowed");
        floorERC1155AssetModule.processIndirectDeposit(
            address(creditorUsd), asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }
}
