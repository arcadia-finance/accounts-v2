/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "setRiskManager" of contract "AbstractPricingModule".
 */
contract SetRiskManager_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testSuccess_setRiskManager(address newRiskManager) public {
        assertEq(pricingModule.riskManager(), users.creatorAddress);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(newRiskManager);
        pricingModule.setRiskManager(newRiskManager);
        vm.stopPrank();

        assertEq(pricingModule.riskManager(), newRiskManager);
    }

    function testRevert_setRiskManager_NonRiskManager(address newRiskManager, address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        assertEq(pricingModule.riskManager(), users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        pricingModule.setRiskManager(newRiskManager);
        vm.stopPrank();

        assertEq(pricingModule.riskManager(), users.creatorAddress);
    }
}
