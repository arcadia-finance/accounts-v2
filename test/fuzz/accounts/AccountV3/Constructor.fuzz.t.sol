/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AccountV3".
 */
contract Constructor_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_, address merklDistributor) public {
        vm.prank(users.owner);
        AccountV3 account_ = new AccountV3(factory_, address(accountsGuard), merklDistributor);

        assertEq(account_.FACTORY(), factory_);
        assertEq(address(account_.MERKL_DISTRIBUTOR()), merklDistributor);
    }
}
