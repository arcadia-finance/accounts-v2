/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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

    // Flag indicating if the Account is in an auction (in liquidation).
    bool public inAuction;
    // Flag Indicating if a function is locked to protect against reentrancy.
    uint8 internal locked;
    // Used to prevent the old Owner from frontrunning a transferFrom().
    // The Timestamp of the last account action, that might be disadvantageous for a new Owner
    // (withdrawals, change of Creditor, increasing liabilities...).
    uint32 public lastActionTimestamp;
    // The contract address of the liquidator, address 0 if no creditor is set.
    address public liquidator;

    // The minimum amount of collateral that must be held in the Account before a position can be opened, denominated in the numeraire.
    // Will count as Used Margin after a position is opened.
    uint96 public minimumMargin;
    // The contract address of the Registry.
    address public registry;

    // The owner of the Account.
    address public owner;
    // The contract address of the Creditor.
    address public creditor;
    // The Numeraire (the unit in which prices are measured) of the Account,
    // in which all assets and liabilities are denominated.
    address public numeraire;

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
    // Map owner => approved Creditor.
    // This is a Creditor for which a margin Account can be opened later in time to e.g. refinance liabilities.
    mapping(address => address) public approvedCreditor;
    // Map owner => assetManager => flag.
    mapping(address => mapping(address => bool)) public isAssetManager;
}
