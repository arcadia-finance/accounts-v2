/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "ownerOfAccount" of contract "Factory".
 */
contract OwnerOfAccount_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_ownerOfAccount_NonAccount(address nonAccount) public {
        vm.assume(nonAccount != address(proxyAccount));

        assertEq(factory.ownerOfAccount(nonAccount), address(0));
    }
}
