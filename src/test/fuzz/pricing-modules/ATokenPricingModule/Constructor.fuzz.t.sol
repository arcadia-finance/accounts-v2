/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, ATokenPricingModule_Fuzz_Test } from "./_ATokenPricingModule.fuzz.t.sol";

import { ATokenPricingModule } from "../../../../pricing-modules/ATokenPricingModule.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "ATokenPricingModule".
 */
contract Constructor_ATokenPricingModule_Fuzz_Test is ATokenPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ATokenPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(
        address mainRegistry_,
        address oracleHub_,
        uint256 assetType_,
        address erc20PricingModule_
    ) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(users.creatorAddress);
        ATokenPricingModule aTokenPricingModule_ = new ATokenPricingModule(
            mainRegistry_,
            oracleHub_,
            assetType_,
            erc20PricingModule_
        );
        vm.stopPrank();

        assertEq(aTokenPricingModule_.mainRegistry(), mainRegistry_);
        assertEq(aTokenPricingModule_.oracleHub(), oracleHub_);
        assertEq(aTokenPricingModule_.assetType(), assetType_);
        assertEq(aTokenPricingModule_.erc20PricingModule(), erc20PricingModule_);
        assertEq(aTokenPricingModule_.riskManager(), users.creatorAddress);
    }
}
