/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AccountV4".
 */
contract Constructor_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_, address merklDistributor) public {
        vm.prank(users.owner);
        AccountV4 account_ = new AccountV4(factory_, address(accountsGuard), merklDistributor);

        assertEq(account_.FACTORY(), factory_);
        assertEq(address(account_.MERKL_DISTRIBUTOR()), merklDistributor);
    }
}
