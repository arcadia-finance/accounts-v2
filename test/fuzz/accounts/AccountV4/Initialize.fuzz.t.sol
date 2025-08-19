/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";
import { AccountV4Extension } from "../../../utils/extensions/AccountV4Extension.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "AccountV4".
 */
contract Initialize_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV4Extension internal account_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();

        account_ = new AccountV4Extension(address(factory), address(accountsGuard));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account_)).checked_write(
            true
        );
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

        vm.startPrank(notFactory);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        account_.initialize(owner_, registry_, creditor_);
        vm.stopPrank();
    }

    function testFuzz_Revert_initialize_Invalidregistry(address owner_, address creditor_) public {
        vm.prank(address(factory));
        vm.expectRevert(AccountErrors.InvalidRegistry.selector);
        account_.initialize(owner_, address(0), creditor_);
    }

    function testFuzz_Success_initialize(address owner_, address registry_, address creditor_) public {
        vm.prank(address(factory));
        account_.initialize(owner_, registry_, creditor_);

        assertEq(account_.owner(), owner_);
        assertEq(account_.registry(), registry_);
        assertEq(account_.creditor(), address(0));
    }
}
