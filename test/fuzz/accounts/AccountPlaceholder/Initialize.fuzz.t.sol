/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountPlaceholder_Fuzz_Test } from "./_AccountPlaceholder.fuzz.t.sol";
import { AccountPlaceholderExtension } from "../../../utils/extensions/AccountPlaceholderExtension.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "AccountPlaceholder".
 */
contract Initialize_AccountPlaceholder_Fuzz_Test is AccountPlaceholder_Fuzz_Test {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountPlaceholder_Fuzz_Test.setUp();

        account_ = new AccountPlaceholderExtension(address(factory), address(accountsGuard), 1);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account_))
            .checked_write(true);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_initialize_NotFactory(
        address notFactory,
        address owner_,
        address registry_,
        address creditor_
    ) public {
        vm.assume(notFactory != address(factory));

        vm.prank(notFactory);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        account_.initialize(owner_, registry_, creditor_);
    }

    function testFuzz_Revert_initialize_Reentered(address owner_, address registry_, address creditor_) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        vm.prank(address(factory));
        vm.expectRevert(AccountsGuard.Reentered.selector);
        account_.initialize(owner_, registry_, creditor_);
    }

    function testFuzz_Revert_initialize_InvalidRegistry(address owner_, address creditor_) public {
        vm.prank(address(factory));
        vm.expectRevert(AccountErrors.InvalidRegistry.selector);
        account_.initialize(owner_, address(0), creditor_);
    }

    function testFuzz_Success_initialize(address owner_, address registry_, address creditor_) public {
        vm.assume(registry_ != address(0));

        vm.prank(address(factory));
        account_.initialize(owner_, registry_, creditor_);

        assertEq(account_.owner(), owner_);
        assertEq(account_.registry(), registry_);
        assertEq(account_.creditor(), address(0));
    }
}
