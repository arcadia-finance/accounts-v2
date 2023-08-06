/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.13;

interface IVault {
    function trustedCreditor() external returns (address);
    function isTrustedCreditorSet() external returns (bool);
    function fixedLiquidationCost() external returns (uint256);
    function baseCurrency() external returns (address);
    function liquidator() external returns (address);
    function openTrustedMarginAccount(address) external;
}
