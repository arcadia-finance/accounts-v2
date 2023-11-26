/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMaxRecursiveCalls" of contract "Registry".
 */
contract SetMaxRecursiveCalls_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMaxRecursiveCalls_NonRiskManager(
        address unprivilegedAddress_,
        uint256 maxRecursiveCalls
    ) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registryExtension.setMaxRecursiveCalls(address(creditorUsd), maxRecursiveCalls);
        vm.stopPrank();
    }

    function testFuzz_Success_setMaxRecursiveCalls(uint256 maxRecursiveCalls) public {
        vm.prank(users.riskManager);
        registryExtension.setMaxRecursiveCalls(address(creditorUsd), maxRecursiveCalls);

        uint256 actualMaxRecursionDepth = registryExtension.maxRecursiveCalls(address(creditorUsd));

        assertEq(actualMaxRecursionDepth, maxRecursiveCalls);
    }
}
