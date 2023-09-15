/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processDeposit" of contract "FloorERC1155PricingModule".
 */
contract ProcessDeposit_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        uint128 amount,
        address account_
    ) public {
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC1155PricingModule.processDeposit(account_, address(mockERC1155.sft2), 1, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDeposit_OverExposure(uint128 amount, uint128 maxExposure, address account_)
        public
    {
        vm.assume(maxExposure > 0); //Asset is whitelisted
        vm.assume(amount > maxExposure);
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput, maxExposure
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM1155_PD: Exposure not in limits");
        floorERC1155PricingModule.processDeposit(account_, address(mockERC1155.sft2), 1, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDeposit_WrongID(uint256 assetId, uint128 amount, address account_) public {
        vm.assume(assetId > 0); //Wrong Id
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 0, oracleSft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM1155_PD: ID not allowed");
        floorERC1155PricingModule.processDeposit(account_, address(mockERC1155.sft2), assetId, amount);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC1155PricingModule.exposure(address(mockERC1155.sft2));
        assertEq(actualExposure, 0);
    }

    function testFuzz_Success_processDeposit_Positive(uint128 amount, address account_) public {
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.prank(address(mainRegistryExtension));
        floorERC1155PricingModule.processDeposit(account_, address(mockERC1155.sft2), 1, amount);

        (, uint128 actualExposure) = floorERC1155PricingModule.exposure(address(mockERC1155.sft2));
        assertEq(actualExposure, amount);
    }
}
