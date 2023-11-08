/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

import { FloorERC1155PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "FloorERC1155PricingModule".
 */
contract Constructor_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_, address oracleHub_) public {
        vm.startPrank(users.creatorAddress);
        FloorERC1155PricingModuleExtension pricingModule_ = new FloorERC1155PricingModuleExtension(
            mainRegistry_,
            oracleHub_);
        vm.stopPrank();

        assertEq(pricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(pricingModule_.ORACLE_HUB(), oracleHub_);
        assertEq(pricingModule_.ASSET_TYPE(), 2);
        assertTrue(pricingModule_.getPrimaryFlag());
    }
}
