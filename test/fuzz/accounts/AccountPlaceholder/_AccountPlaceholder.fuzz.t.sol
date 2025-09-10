/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountPlaceholderExtension } from "../../../utils/extensions/AccountPlaceholderExtension.sol";
import { Constants } from "../../../utils/Constants.sol";
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
        accountPlaceholderLogic = new AccountPlaceholderExtension(address(factory), address(accountsGuard), 4);
        vm.prank(users.owner);
        factory.setNewAccountInfo(address(registry), address(accountPlaceholderLogic), Constants.ROOT, "");

        vm.prank(users.accountOwner);
        address payable proxyAddress = payable(factory.createAccount(1001, 4, address(0)));
        account_ = AccountPlaceholderExtension(proxyAddress);
    }
}
