/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./UniswapV3PricingModule.fuzz.t.sol";

import { UniswapV3WithFeesPricingModule_UsdOnly } from
    "../../../../pricing-modules/UniswapV3/UniswapV3WithFeesPricingModule_UsdOnly.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "UniswapV3PricingModule".
 */
contract Constructor_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_deployment(address mainRegistry_, address oracleHub_, address riskManager_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RiskManagerUpdated(riskManager_);
        UniswapV3WithFeesPricingModule_UsdOnly erc20PricingModule_ = new UniswapV3WithFeesPricingModule_UsdOnly(
            mainRegistry_,
            oracleHub_,
            riskManager_,
            address(erc20PricingModule)
        );
        vm.stopPrank();

        assertEq(erc20PricingModule_.mainRegistry(), mainRegistry_);
        assertEq(erc20PricingModule_.oracleHub(), oracleHub_);
        assertEq(erc20PricingModule_.assetType(), 1);
        assertEq(erc20PricingModule_.riskManager(), riskManager_);
    }
}
