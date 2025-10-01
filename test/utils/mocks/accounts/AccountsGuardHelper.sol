/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuardExtension } from "../../extensions/AccountsGuardExtension.sol";
import { AccountStorageV1 } from "../../../../src/accounts/AccountStorageV1.sol";

contract AccountsGuardHelper is AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Accounts Guard.
    AccountsGuardExtension public immutable ACCOUNTS_GUARD;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    constructor(address accountsGuard) {
        ACCOUNTS_GUARD = AccountsGuardExtension(accountsGuard);
    }

    function lockWitInitialState(address initialState, bool pauseCheck) external returns (address endState) {
        ACCOUNTS_GUARD.setAccount(initialState);

        ACCOUNTS_GUARD.lock(pauseCheck);

        endState = ACCOUNTS_GUARD.getAccount();
    }

    function unlockWitInitialState(address initialState) external returns (address endState) {
        ACCOUNTS_GUARD.setAccount(initialState);

        ACCOUNTS_GUARD.unLock();

        endState = ACCOUNTS_GUARD.getAccount();
    }
}
