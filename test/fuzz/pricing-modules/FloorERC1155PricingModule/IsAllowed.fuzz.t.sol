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
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Positive() public {
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr);

        assertTrue(floorERC1155PricingModule.isAllowed(address(mockERC1155.sft2), 1));
    }

    function testFuzz_Success_isAllowed_NegativeWrongAddress(address randomAsset) public {
        assertFalse(floorERC1155PricingModule.isAllowed(randomAsset, 1));
    }

    function testFuzz_Success_isAllowed_NegativeIdOutsideRange(uint256 id) public {
        vm.assume(id != 1);
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(address(mockERC1155.sft2), 1, oracleSft2ToUsdArr);

        assertFalse(floorERC1155PricingModule.isAllowed(address(mockERC1155.sft2), id));
    }
}
