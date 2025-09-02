/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IAccountsGuard {
    function lock(bool pauseCheck, bytes4 selector) external;

    function unLock() external;
}
