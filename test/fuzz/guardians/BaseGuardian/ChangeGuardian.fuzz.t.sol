/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { BaseGuardian_Fuzz_Test } from "./_BaseGuardian.fuzz.t.sol";

import { BaseGuardian } from "../../../../src/guardians/BaseGuardian.sol";

/**
 * @notice Fuzz tests for the function "changeGuardian" of contract "BaseGuardian".
 */
contract ChangeGuardian_BaseGuardian_Fuzz_Test is BaseGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        BaseGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_changeGuardian_onlyOwner(address nonOwner, address newGuardian) public {
        vm.assume(nonOwner != users.owner);

        vm.startPrank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        baseGuardian.changeGuardian(newGuardian);
        vm.stopPrank();
    }

    function testFuzz_Success_changeGuardian(address newGuardian) public {
        vm.startPrank(users.owner);
        vm.expectEmit(true, true, true, true);
        emit BaseGuardian.GuardianChanged(users.owner, newGuardian);
        baseGuardian.changeGuardian(newGuardian);
        vm.stopPrank();

        assertEq(baseGuardian.guardian(), newGuardian);
    }
}
