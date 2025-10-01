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
        AccountPlaceholder account__ = new AccountPlaceholder(factory_, accountsGuard_, version);

        assertEq(account__.FACTORY(), factory_);
        assertEq(address(account__.ACCOUNTS_GUARD()), accountsGuard_);
        assertEq(account__.ACCOUNT_VERSION(), version);
    }
}
