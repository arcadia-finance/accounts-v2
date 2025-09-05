/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FloorERC1155AM_Fuzz_Test, AssetModule } from "./_FloorERC1155AM.fuzz.t.sol";

import { FloorERC1155AM } from "../../../utils/mocks/asset-modules/FloorERC1155AM.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "FloorERC1155AM".
 */
contract ProcessDirectDeposit_FloorERC1155AM_Fuzz_Test is FloorERC1155AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(address unprivilegedAddress_, uint128 amount) public {
        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, type(uint112).max, 0, 0
        );

        vm.assume(unprivilegedAddress_ != address(registry));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        floorERC1155AM.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 1, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(uint128 amount, uint112 maxExposure) public {
        vm.assume(maxExposure > 0); //Asset is allowed
        vm.assume(amount >= maxExposure);
        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC1155.sft2), 1, maxExposure, 0, 0);

        vm.startPrank(address(registry));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        floorERC1155AM.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 1, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_WrongID(uint96 assetId, uint128 amount) public {
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 0, oraclesSft2ToUsd);

        vm.startPrank(address(registry));
        vm.expectRevert(FloorERC1155AM.AssetNotAllowed.selector);
        floorERC1155AM.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), assetId, amount);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(mockERC1155.sft2)));
        (uint112 actualExposure,,,) = floorERC1155AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }

    function testFuzz_Success_processDirectDeposit(uint112 amount) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        amount = uint112(bound(amount, 0, type(uint112).max - 1));

        vm.prank(users.owner);
        floorERC1155AM.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, type(uint112).max, 0, 0
        );

        vm.prank(address(registry));
        uint256 recursiveCalls =
            floorERC1155AM.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 1, amount);

        assertEq(recursiveCalls, 1);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft2)));
        (uint112 actualExposure,,,) = floorERC1155AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, amount);
    }
}
