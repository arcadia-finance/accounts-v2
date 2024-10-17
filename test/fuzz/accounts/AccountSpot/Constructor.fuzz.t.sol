/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";

import { AccountSpot } from "../../../../src/accounts/AccountSpot.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AccountSpot".
 */
contract Constructor_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_) public {
        vm.prank(users.owner);
        AccountSpot account_ = new AccountSpot(factory_);

        assertEq(account_.FACTORY(), factory_);
    }
}
