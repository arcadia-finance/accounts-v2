/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC1155PricingModule_Fuzz_Test } from "./FloorERC1155PricingModule.fuzz.t.sol";

import { FloorERC1155PricingModule } from "../../../../pricing-modules/FloorERC1155PricingModule.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "FloorERC1155PricingModule".
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
    function testSuccess_deployment(address mainRegistry_, address oracleHub_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(users.creatorAddress);
        FloorERC1155PricingModule pricingModule_ = new FloorERC1155PricingModule(
            mainRegistry_,
            oracleHub_,
            assetType_
        );
        vm.stopPrank();

        assertEq(pricingModule_.mainRegistry(), mainRegistry_);
        assertEq(pricingModule_.oracleHub(), oracleHub_);
        assertEq(pricingModule_.assetType(), assetType_);
        assertEq(pricingModule_.riskManager(), users.creatorAddress);
    }
}
