/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { AbstractPricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "AbstractPricingModule".
 */
contract Constructor_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(
        address mainRegistry_,
        address oracleHub_,
        address riskManager_,
        uint256 assetType_
    ) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        AbstractPricingModuleExtension pricingModule_ = new AbstractPricingModuleExtension(
            mainRegistry_,
            oracleHub_,
            assetType_,
            riskManager_
        );
        vm.stopPrank();

        assertEq(pricingModule_.mainRegistry(), mainRegistry_);
        assertEq(pricingModule_.oracleHub(), oracleHub_);
        assertEq(pricingModule_.assetType(), assetType_);
        assertEq(pricingModule_.riskManager(), riskManager_);
    }
}
