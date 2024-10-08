/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountSpotExtension } from "../../../utils/extensions/AccountSpotExtension.sol";
import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "AccountSpot".
 */
contract Initialize_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountSpotExtension internal account_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountSpot_Fuzz_Test.setUp();

        account_ = new AccountSpotExtension(address(factory));
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

    function testFuzz_Success_initialize(address owner_, address creditor_) public {
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
        assertEq(account_.getLocked(), 1);
    }
}
