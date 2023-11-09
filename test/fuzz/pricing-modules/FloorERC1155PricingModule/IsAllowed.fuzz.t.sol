/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "FloorERC1155PricingModule".
 */
contract IsAllowed_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oraclesSft2ToUsd);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Positive() public {
        assertTrue(floorERC1155PricingModule.isAllowed(address(mockERC1155.sft2), 1));
    }

    function testFuzz_Success_isAllowed_Negative(address randomAsset, uint256 randomId) public {
        vm.assume(randomAsset != address(mockERC1155.sft2) && randomId != 1);
        assertFalse(floorERC1155PricingModule.isAllowed(randomAsset, randomId));
    }
}
