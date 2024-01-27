/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC1155AM_Fuzz_Test, AssetModule } from "./_FloorERC1155AM.fuzz.t.sol";

import { FloorERC1155AM } from "../../../utils/mocks/asset-modules/FloorERC1155AM.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "FloorERC1155AM".
 */
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
        vm.assume(unprivilegedAddress_ != address(registryExtension));

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
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(users.creatorAddress);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);

        vm.startPrank(address(registryExtension));
        vm.expectRevert(FloorERC1155AM.AssetNotAllowed.selector);
        floorERC1155AM.processIndirectDeposit(
            address(creditorUsd), asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    //todo: add success tests
}
