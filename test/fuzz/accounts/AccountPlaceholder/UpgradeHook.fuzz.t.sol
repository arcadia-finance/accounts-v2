/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountPlaceholder_Fuzz_Test } from "./_AccountPlaceholder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "upgradeHook" of contract "AccountPlaceholder".
 */
contract UpgradeHook_AccountPlaceholder_Fuzz_Test is AccountPlaceholder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountPlaceholder_Fuzz_Test) {
        AccountPlaceholder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_upgradeHook_NonSelf(
        address caller,
        address oldImplementation,
        address oldRegistry,
        uint256 oldVersion,
        bytes calldata data
    ) public {
        // When: Caller calls upgradeHook.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountErrors.InvalidUpgrade.selector);
        account_.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);
    }
}
