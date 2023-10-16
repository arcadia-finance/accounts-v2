/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { UniswapV2PricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "UniswapV2PricingModule".
 */
contract Constructor_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        assertEq(uniswapV2PricingModule.MAIN_REGISTRY(), address(mainRegistryExtension));
        assertEq(uniswapV2PricingModule.ORACLE_HUB(), address(oracleHub));
        assertEq(uniswapV2PricingModule.ASSET_TYPE(), 0);
        assertEq(uniswapV2PricingModule.getUniswapV2Factory(), address(uniswapV2Factory));
    }
}
