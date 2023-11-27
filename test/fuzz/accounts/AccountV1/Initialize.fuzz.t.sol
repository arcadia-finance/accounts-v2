/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "AccountV1".
 */
contract Initialize_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountNotInitialised;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        accountNotInitialised = new AccountExtension();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_initialize_InvalidReg() public {
        vm.expectRevert(AccountErrors.InvalidRegistry.selector);
        accountNotInitialised.initialize(users.accountOwner, address(0), address(0), address(0));
    }

    function testFuzz_Revert_initialize_AlreadyInitialized() public {
        accountNotInitialised.initialize(users.accountOwner, address(registryExtension), address(0), address(0));

        vm.expectRevert(AccountErrors.AlreadyInitialized.selector);
        accountNotInitialised.initialize(users.accountOwner, address(registryExtension), address(0), address(0));
    }

    function testFuzz_Success_initialize(address owner_) public {
        vm.expectEmit(true, true, true, true);
        emit NumeraireSet(address(0));
        accountNotInitialised.initialize(owner_, address(registryExtension), address(0), address(0));

        assertEq(accountNotInitialised.owner(), owner_);
        assertEq(accountNotInitialised.getLocked(), 1);
        assertEq(accountNotInitialised.registry(), address(registryExtension));
        assertEq(accountNotInitialised.numeraire(), address(0));
    }
}
