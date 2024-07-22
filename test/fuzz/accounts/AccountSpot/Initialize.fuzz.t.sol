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

    AccountSpotExtension internal accountNotInitialised;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountSpot_Fuzz_Test.setUp();

        accountNotInitialised = new AccountSpotExtension(address(factory));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_initialize_NotFactory(address notFactory) public {
        vm.assume(notFactory != address(factory));

        vm.startPrank(notFactory);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        accountNotInitialised.initialize(users.accountOwner, address(0), address(0));
        vm.stopPrank();
    }

    function testFuzz_Success_initialize(address owner_) public {
        vm.prank(address(factory));
        accountNotInitialised.initialize(owner_, address(0), address(0));

        assertEq(accountNotInitialised.owner(), owner_);
        assertEq(accountNotInitialised.getLocked(), 1);
    }
}
