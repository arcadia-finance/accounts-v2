/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Gas_Test } from "../Gas.t.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "AccountV1".
 */
contract CreateAccount_Factory_Gas_Test is Gas_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Gas_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testGas_CreateAccount() public {
        vm.prank(users.accountOwner);
        factory.createAccount(1_000_000, 0, address(creditorStable1));
    }
}
