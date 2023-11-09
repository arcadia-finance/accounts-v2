/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ChainLinkOracleModule_Fuzz_Test } from "./_ChainLinkOracleModule.fuzz.t.sol";

import { ChainLinkOracleModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "ChainLinkOracleModule".
 */
contract Constructor_ChainLinkOracleModule_Fuzz_Test is ChainLinkOracleModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_) public {
        vm.startPrank(users.creatorAddress);
        ChainLinkOracleModuleExtension oracleModule_ = new ChainLinkOracleModuleExtension(
            mainRegistry_
        );
        vm.stopPrank();

        assertEq(oracleModule_.MAIN_REGISTRY(), mainRegistry_);
    }
}
