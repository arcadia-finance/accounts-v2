/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAccount" of contract "Factory".
 */
contract IsAccount_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAccount_positive() public {
        address newAccount = factory.createAccount(2, 0, address(0));

        assertTrue(factory.isAccount(newAccount));
    }

    function testFuzz_Success_isAccount_negative(address random) public {
        vm.assume(random != address(proxyAccount));

        assertFalse(factory.isAccount(random));
    }
}
