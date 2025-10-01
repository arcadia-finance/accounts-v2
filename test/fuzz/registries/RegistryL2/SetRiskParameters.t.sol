/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "RegistryL2".
 */
contract SetRiskParameters_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonRiskManager(
        address unprivilegedAddress_,
        uint128 minUsdValue,
        uint64 gracePeriod,
        uint64 maxRecursiveCalls
    ) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registry.setRiskParameters(address(creditorUsd), minUsdValue, gracePeriod, maxRecursiveCalls);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(uint128 minUsdValue, uint64 gracePeriod, uint64 maxRecursiveCalls)
        public
    {
        vm.prank(users.riskManager);
        registry.setRiskParameters(address(creditorUsd), minUsdValue, gracePeriod, maxRecursiveCalls);

        (uint256 minUsdValue_, uint256 gracePeriod_, uint256 maxRecursiveCalls_) =
            registry.riskParams(address(creditorUsd));

        assertEq(minUsdValue_, minUsdValue);
        assertEq(gracePeriod_, gracePeriod);
        assertEq(maxRecursiveCalls_, maxRecursiveCalls);
    }
}
