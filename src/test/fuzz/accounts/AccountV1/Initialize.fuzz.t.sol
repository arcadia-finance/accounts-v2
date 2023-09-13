/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./AccountV1.fuzz.t.sol";

import { AccountExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "initialize" of contract "AccountV1".
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
    function testRevert_initialize_InvalidMainreg() public {
        vm.expectRevert("A_I: Registry cannot be 0!");
        accountNotInitialised.initialize(users.accountOwner, address(0), address(0), address(0));
    }

    function testRevert_initialize_AlreadyInitialized() public {
        accountNotInitialised.initialize(users.accountOwner, address(mainRegistryExtension), address(0), address(0));

        vm.expectRevert("A_I: Already initialized!");
        accountNotInitialised.initialize(users.accountOwner, address(mainRegistryExtension), address(0), address(0));
    }

    function test_initialize(address owner_) public {
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencySet(address(0));
        accountNotInitialised.initialize(owner_, address(mainRegistryExtension), address(0), address(0));

        assertEq(accountNotInitialised.owner(), owner_);
        assertEq(accountNotInitialised.getLocked(), 1);
        assertEq(accountNotInitialised.registry(), address(mainRegistryExtension));
        assertEq(accountNotInitialised.baseCurrency(), address(0));
    }
}
