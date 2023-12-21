/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { RegistryExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "Registry".
 */
contract Constructor_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address sequencerUptimeOracle_) public {
        vm.startPrank(users.creatorAddress);
        RegistryExtension registry = new RegistryExtension(address(factory), sequencerUptimeOracle_);
        vm.stopPrank();

        assertEq(registry.FACTORY(), address(factory));
        assertEq(registry.getSequencerUptimeOracle(), sequencerUptimeOracle_);
    }
}
