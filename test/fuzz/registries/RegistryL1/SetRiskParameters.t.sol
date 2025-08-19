/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryL1_Fuzz_Test, RegistryErrors } from "./_RegistryL1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "RegistryL1".
 */
contract SetRiskParameters_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonRiskManager(
        address unprivilegedAddress_,
        uint128 minUsdValue,
        uint64 maxRecursiveCalls
    ) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registry_.setRiskParameters(address(creditorUsd), minUsdValue, maxRecursiveCalls);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(uint128 minUsdValue, uint64 maxRecursiveCalls) public {
        vm.prank(users.riskManager);
        registry_.setRiskParameters(address(creditorUsd), minUsdValue, maxRecursiveCalls);

        (uint256 minUsdValue_, uint256 maxRecursiveCalls_) = registry_.riskParams(address(creditorUsd));

        assertEq(minUsdValue_, minUsdValue);
        assertEq(maxRecursiveCalls_, maxRecursiveCalls);
    }
}
