/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setRiskParametersOfDerivedAssetModule" of contract "Registry".
 */
contract SetMaxRecursionDepth_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMaxRecursionDepth_NonRiskManager(
        address unprivilegedAddress_,
        uint256 maxRecursionDepth
    ) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registryExtension.setMaxRecursionDepth(address(creditorUsd), maxRecursionDepth);
        vm.stopPrank();
    }

    function testFuzz_Success_setMaxRecursionDepth(uint256 maxRecursionDepth) public {
        vm.prank(users.riskManager);
        registryExtension.setMaxRecursionDepth(address(creditorUsd), maxRecursionDepth);

        uint256 actualMaxRecursionDepth = registryExtension.maxRecursionDepthCreditor(address(creditorUsd));

        assertEq(actualMaxRecursionDepth, maxRecursionDepth);
    }
}
