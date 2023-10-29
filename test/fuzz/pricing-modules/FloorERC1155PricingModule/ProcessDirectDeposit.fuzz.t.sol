/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "FloorERC1155PricingModule".
 */
contract ProcessDirectDeposit_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(address unprivilegedAddress_, uint128 amount)
        public
    {
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, type(uint128).max, 0, 0
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC1155PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 1, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(uint128 amount, uint128 maxExposure) public {
        vm.assume(maxExposure > 0); //Asset is allowed
        vm.assume(amount > maxExposure);
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, maxExposure, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_PDD: Exposure not in limits");
        floorERC1155PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 1, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_WrongID(uint256 assetId, uint128 amount) public {
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 0, oracleSft2ToUsdArr);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM1155_PDD: ID not allowed");
        floorERC1155PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), assetId, amount);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft2)));
        (uint128 actualExposure,,,) = floorERC1155PricingModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }

    function testFuzz_Success_processDirectDeposit(uint128 amount) public {
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, type(uint128).max, 0, 0
        );

        vm.prank(address(mainRegistryExtension));
        floorERC1155PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC1155.sft2), 1, amount);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(1), address(mockERC1155.sft2)));
        (uint128 actualExposure,,,) = floorERC1155PricingModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, amount);
    }
}
