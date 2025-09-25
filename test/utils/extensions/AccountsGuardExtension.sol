/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../../src/accounts/helpers/AccountsGuard.sol";

contract AccountsGuardExtension is AccountsGuard {
    constructor(address owner_, address factory) AccountsGuard(owner_, factory) { }

    function getAccount() external view returns (address account_) {
        account_ = account;
    }

    function setAccount(address account_) external {
        account = account_;
    }
}
