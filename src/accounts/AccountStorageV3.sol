/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountStorageV1 } from "./AccountStorageV1.sol";

/**
 * @title Arcadia Accounts Storage
 * @author Pragma Labs
 * @notice This contract is the storage contract for the Accounts.
 * Arcadia Accounts are smart contracts that act as onchain, decentralized and composable margin accounts.
 * They provide individuals, DAOs, and other protocols with a simple and flexible way to deposit and manage multiple assets as collateral.
 * More detail about the Accounts can be found in the AccountsV1.sol contract.
 * @dev Since Accounts are proxies and can be upgraded by the user, all storage variables should be declared in this contract.
 * New account versions must create a new account storage contract and inherit this storage contract.
 */
contract AccountStorageV3 is AccountStorageV1 { }
