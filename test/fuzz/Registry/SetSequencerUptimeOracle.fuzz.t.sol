/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { SequencerUptimeOracle } from "../../utils/mocks/oracles/SequencerUptimeOracle.sol";

/**
 * @notice Fuzz tests for the function "setSequencerUptimeOracle" of contract "Registry".
 */
contract SetSequencerUptimeOracle_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setSequencerUptimeOracle_NonOwner(
        address unprivilegedAddress,
        address sequencerUptimeOracle_
    ) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress != users.creatorAddress);

        // When: unprivilegedAddress_ calls setSequencerUptimeOracle
        // Then: Function reverts with "UNAUTHORIZED"
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        registryExtension.setSequencerUptimeOracle(sequencerUptimeOracle_);
    }

    function testFuzz_Revert_setSequencerUptimeOracle_OracleNotReverting(address sequencerUptimeOracle_) public {
        // Given: Current sequencer oracle is active.
        // When: creatorAddress calls setSequencerUptimeOracle with new oracle.
        // Then: Function reverts with OracleNotReverting.
        vm.prank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.OracleNotReverting.selector);
        registryExtension.setSequencerUptimeOracle(sequencerUptimeOracle_);
    }

    function testFuzz_Revert_setSequencerUptimeOracle_OracleReverting() public {
        // Given: Current sequencer oracle reverts.
        sequencerUptimeOracle.setRevertsFlag(true);

        // And: New sequencer oracle reverts.
        SequencerUptimeOracle sequencerUptimeOracle_ = new SequencerUptimeOracle();
        sequencerUptimeOracle_.setRevertsFlag(true);

        // When: creatorAddress calls setSequencerUptimeOracle with new oracle.
        // Then: Function reverts with OracleReverting.
        vm.prank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.OracleReverting.selector);
        registryExtension.setSequencerUptimeOracle(address(sequencerUptimeOracle_));
    }

    function testFuzz_Success_setSequencerUptimeOracle() public {
        // Given: Current sequencer oracle reverts.
        sequencerUptimeOracle.setRevertsFlag(true);

        // And: New sequencer oracle is active.
        SequencerUptimeOracle sequencerUptimeOracle_ = new SequencerUptimeOracle();

        // When: creatorAddress calls setSequencerUptimeOracle with new oracle.
        vm.prank(users.creatorAddress);
        registryExtension.setSequencerUptimeOracle(address(sequencerUptimeOracle_));

        // Then: New sequencer oracle is set.
        assertEq(registryExtension.getSequencerUptimeOracle(), address(sequencerUptimeOracle_));
    }
}
