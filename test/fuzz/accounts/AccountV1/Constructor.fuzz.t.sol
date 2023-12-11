/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AccountV1".
 */
contract Constructor_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_) public {
        vm.prank(users.creatorAddress);
        AccountV1 account_ = new AccountV1(factory_);

        assertEq(account_.FACTORY(), factory_);
    }
}
