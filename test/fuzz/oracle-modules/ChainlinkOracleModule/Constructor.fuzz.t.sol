/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ChainlinkOracleModule_Fuzz_Test } from "./_ChainlinkOracleModule.fuzz.t.sol";

import { ChainlinkOracleModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "ChainlinkOracleModule".
 */
contract Constructor_ChainlinkOracleModule_Fuzz_Test is ChainlinkOracleModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        ChainlinkOracleModuleExtension oracleModule_ = new ChainlinkOracleModuleExtension(registry_);
        vm.stopPrank();

        assertEq(oracleModule_.REGISTRY(), registry_);
    }
}
