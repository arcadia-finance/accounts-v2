/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */

pragma solidity ^0.8.13;

interface IVault {
    function trustedCreditor() external returns (address);
    function isTrustedCreditorSet() external returns (bool);
}
