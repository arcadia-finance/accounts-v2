/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMinUsdValue" of contract "Registry".
 */
contract SetMinUsdValue_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMinUsdValue_NonRiskManager(address unprivilegedAddress_, uint256 minUsdValue) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registryExtension.setMinUsdValue(address(creditorUsd), minUsdValue);
        vm.stopPrank();
    }

    function testFuzz_Success_setMinUsdValue(uint256 minUsdValue) public {
        vm.prank(users.riskManager);
        registryExtension.setMinUsdValue(address(creditorUsd), minUsdValue);

        uint256 actualMaxRecursionDepth = registryExtension.minUsdValue(address(creditorUsd));

        assertEq(actualMaxRecursionDepth, minUsdValue);
    }
}
