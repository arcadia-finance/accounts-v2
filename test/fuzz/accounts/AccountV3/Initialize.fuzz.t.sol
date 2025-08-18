/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "AccountV3".
 */
contract Initialize_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV3Extension internal accountNotInitialised;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();

        accountNotInitialised = new AccountV3Extension(address(factory), address(accountsGuard));
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountNotInitialised))
            .checked_write(true);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_initialize_InvalidReg() public {
        vm.expectRevert(AccountErrors.InvalidRegistry.selector);
        accountNotInitialised.initialize(users.accountOwner, address(0), address(0));
    }

    function testFuzz_Revert_initialize_AlreadyInitialized() public {
        accountNotInitialised.initialize(users.accountOwner, address(registry), address(0));

        vm.expectRevert(AccountErrors.AlreadyInitialized.selector);
        accountNotInitialised.initialize(users.accountOwner, address(registry), address(0));
    }

    function testFuzz_Success_initialize_WithoutCreditor(address owner_) public {
        accountNotInitialised.initialize(owner_, address(registry), address(0));

        assertEq(accountNotInitialised.owner(), owner_);
        assertEq(accountNotInitialised.registry(), address(registry));
        assertEq(accountNotInitialised.numeraire(), address(0));
        assertEq(accountNotInitialised.creditor(), address(0));
    }

    function testFuzz_Success_initialize_WithCreditor(address owner_) public {
        vm.expectEmit(true, true, true, true);
        emit AccountV3.NumeraireSet(address(mockERC20.stable1));
        accountNotInitialised.initialize(owner_, address(registry), address(creditorStable1));

        assertEq(accountNotInitialised.owner(), owner_);
        assertEq(accountNotInitialised.registry(), address(registry));
        assertEq(accountNotInitialised.numeraire(), address(mockERC20.stable1));
        assertEq(accountNotInitialised.creditor(), address(creditorStable1));
    }
}
