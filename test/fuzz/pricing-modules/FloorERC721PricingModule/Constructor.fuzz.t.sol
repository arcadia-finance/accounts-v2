/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { FloorERC721PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "FloorERC721PricingModule".
 */
contract Constructor_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_) public {
        vm.startPrank(users.creatorAddress);
        FloorERC721PricingModuleExtension erc721PricingModule_ = new FloorERC721PricingModuleExtension(
            mainRegistry_
            );
        vm.stopPrank();

        assertEq(erc721PricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(erc721PricingModule_.ASSET_TYPE(), 1);
        assertTrue(erc721PricingModule_.getPrimaryFlag());
    }
}
