/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

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
contract AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag Indicating if a function is locked to protect against reentrancy.
    uint256 internal locked;
    // Flag that indicates if a creditor is set.
    bool public isCreditorSet;
    // The contract address of the liquidator, address 0 if no creditor is set.
    address public liquidator;
    // The estimated maximum cost to liquidate an Account, will count as Used Margin when a creditor is set.
    uint96 public fixedLiquidationCost;
    // The owner of the Account.
    address public owner;
    // The contract address of the Registry.
    address public registry;
    // The contract address of the Creditor.
    address public creditor;
    // The baseCurrency of the Account in which all assets and liabilities are denominated.
    address public baseCurrency;

    // Array with all the contract addresses of ERC20 tokens in the account.
    address[] internal erc20Stored;
    // Array with all the contract addresses of ERC721 tokens in the account.
    address[] internal erc721Stored;
    // Array with all the contract addresses of ERC1155 tokens in the account.
    address[] internal erc1155Stored;
    // Array with all the corresponding ids for each ERC721 token in the account.
    uint256[] internal erc721TokenIds;
    // Array with all the corresponding ids for each ERC1155 token in the account.
    uint256[] internal erc1155TokenIds;

    // Map asset => balance.
    mapping(address => uint256) public erc20Balances;
    // Map asset => id => balance.
    mapping(address => mapping(uint256 => uint256)) public erc1155Balances;
    // Map owner => assetManager => flag.
    mapping(address => mapping(address => bool)) public isAssetManager;
}
