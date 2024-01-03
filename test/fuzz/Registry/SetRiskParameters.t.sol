/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "Registry".
 */
contract SetRiskParameters_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
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
        registryExtension.setRiskParameters(address(creditorUsd), minUsdValue, gracePeriod, maxRecursiveCalls);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(uint128 minUsdValue, uint64 gracePeriod, uint64 maxRecursiveCalls)
        public
    {
        vm.prank(users.riskManager);
        registryExtension.setRiskParameters(address(creditorUsd), minUsdValue, gracePeriod, maxRecursiveCalls);

        (uint256 minUsdValue_, uint256 gracePeriod_, uint256 maxRecursiveCalls_) =
            registryExtension.riskParams(address(creditorUsd));

        assertEq(minUsdValue_, minUsdValue);
        assertEq(gracePeriod_, gracePeriod);
        assertEq(maxRecursiveCalls_, maxRecursiveCalls);
    }
}
