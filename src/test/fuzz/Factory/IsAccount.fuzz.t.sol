/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "isAccount" of contract "Factory".
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
        address newAccount = factory.createAccount(1, 0, address(0), address(0));

        bool expectedReturn = factory.isAccount(address(newAccount));
        bool actualReturn = true;

        assertEq(expectedReturn, actualReturn);
    }

    function testFuzz_Success_isAccount_negative(address random) public {
        bool expectedReturn = factory.isAccount(random);
        bool actualReturn = false;

        assertEq(expectedReturn, actualReturn);
    }
}
