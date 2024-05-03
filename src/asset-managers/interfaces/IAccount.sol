/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IAccount {
    function creditor() external returns (address creditor_);
    function flashAction(address actionTarget, bytes calldata actionData) external;
}
