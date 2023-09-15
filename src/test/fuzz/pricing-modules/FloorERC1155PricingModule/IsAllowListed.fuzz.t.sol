/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "isAllowListed" of contract "FloorERC1155PricingModule".
 */
contract IsAllowListed_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_isAllowListed_Positive() public {
        // Given: All necessary contracts deployed on setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: isAllowListed for address(mockERC1155.sft2) should return true
        assertTrue(floorERC1155PricingModule.isAllowListed(address(mockERC1155.sft2), 1));
    }

    function testSuccess_isAllowListed_NegativeWrongAddress(address randomAsset) public {
        // Given: All necessary contracts deployed on setup
        // When: input is randomAsset

        // Then: isAllowListed for randomAsset should return false
        assertTrue(!floorERC1155PricingModule.isAllowListed(randomAsset, 1));
    }

    function testSuccess_isAllowListed_NegativeIdOutsideRange(uint256 id) public {
        // Given: id is not 1
        vm.assume(id != 1);
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );
        vm.stopPrank();

        // Then: isAllowListed for address(interlave) should return false
        assertTrue(!floorERC1155PricingModule.isAllowListed(address(mockERC1155.sft2), id));
    }
}
