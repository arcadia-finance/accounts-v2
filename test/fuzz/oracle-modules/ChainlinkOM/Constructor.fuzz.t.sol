/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ChainlinkOM_Fuzz_Test } from "./_ChainlinkOM.fuzz.t.sol";

import { ChainlinkOMExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "ChainlinkOM".
 */
contract Constructor_ChainlinkOM_Fuzz_Test is ChainlinkOM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        ChainlinkOMExtension oracleModule_ = new ChainlinkOMExtension(registry_);
        vm.stopPrank();

        assertEq(oracleModule_.REGISTRY(), registry_);
    }
}
