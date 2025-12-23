/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountPlaceholder } from "../../../../src/accounts/AccountPlaceholder.sol";
import { AccountPlaceholder_Fuzz_Test } from "./_AccountPlaceholder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AccountPlaceholder".
 */
contract Constructor_AccountPlaceholder_Fuzz_Test is AccountPlaceholder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_, address accountsGuard_, uint256 version) public {
        vm.prank(users.owner);
        AccountPlaceholder account_ = new AccountPlaceholder(factory_, accountsGuard_, version);

        assertEq(account_.FACTORY(), factory_);
        assertEq(address(account_.ACCOUNTS_GUARD()), accountsGuard_);
        assertEq(account_.ACCOUNT_VERSION(), version);
    }
}
