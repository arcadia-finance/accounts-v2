/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";

import { RegistryL2Extension } from "../../../utils/extensions/RegistryL2Extension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "RegistryL2".
 */
contract Constructor_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_deployment_OracleReverting() public {
        sequencerUptimeOracle.setRevertsFlag(true);

        vm.prank(users.owner);
        vm.expectRevert(RegistryErrors.OracleReverting.selector);
        new RegistryL2Extension(users.owner, address(factory), address(sequencerUptimeOracle));
    }

    function testFuzz_Success_deployment() public {
        vm.prank(users.owner);
        RegistryL2Extension registry =
            new RegistryL2Extension(users.owner, address(factory), address(sequencerUptimeOracle));

        assertEq(registry.FACTORY(), address(factory));
        assertEq(registry.getSequencerUptimeOracle(), address(sequencerUptimeOracle));
    }
}
