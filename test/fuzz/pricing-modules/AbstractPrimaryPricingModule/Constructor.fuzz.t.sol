/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

import { PrimaryPricingModuleMock } from "../../../utils/mocks/PrimaryPricingModuleMock.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "AbstractPrimaryPricingModule".
 */
contract Constructor_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_, address oracleHub_, uint256 assetType_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(users.creatorAddress);
        PrimaryPricingModuleMock pricingModule_ = new PrimaryPricingModuleMock(
            mainRegistry_,
            oracleHub_,
            assetType_
        );
        vm.stopPrank();

        assertEq(pricingModule_.MAIN_REGISTRY(), mainRegistry_);
        assertEq(pricingModule_.ORACLE_HUB(), oracleHub_);
        assertEq(pricingModule_.ASSET_TYPE(), assetType_);
        assertEq(pricingModule_.riskManager(), users.creatorAddress);
        assertTrue(pricingModule_.getPrimaryFlag());
    }
}
