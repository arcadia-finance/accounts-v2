/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountPlaceholderExtension } from "../../../utils/extensions/AccountPlaceholderExtension.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "AccountPlaceholder" fuzz tests.
 */
abstract contract AccountPlaceholder_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountPlaceholderExtension internal account_;
    AccountPlaceholderExtension internal accountPlaceholderLogic;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy Account.
        accountPlaceholderLogic = new AccountPlaceholderExtension(
            address(factory), address(accountsGuard), factory.latestAccountVersion() + 1
        );
        vm.prank(users.owner);
        // forge-lint: disable-next-line(unsafe-typecast)
        factory.setNewAccountInfo(address(registry), address(accountPlaceholderLogic), bytes32("1"), "");

        vm.prank(users.accountOwner);
        address payable proxyAddress = payable(factory.createAccount(1001, 0, address(0)));
        account_ = AccountPlaceholderExtension(proxyAddress);
    }
}
