/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/**
 * @title Arcadia Accounts Storage
 * @author Pragma Labs
 * @notice Arcadia Accounts are smart contracts that act as onchain, decentralized and composable margin accounts.
 * They provide individuals, DAOs, and other protocols with a simple and flexible way to deposit and manage multiple assets as collateral.
 * The total combination of assets can be used as margin to back liabilities issued by any financial protocol (lending, leverage, futures...).
 * @dev Users can use this Account to deposit assets (ERC20, ERC721, ERC1155, ...).
 * The Account will denominate all the pooled assets into one baseCurrency (one unit of account, like usd or eth).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Users can use the single denominated value of all their assets to take margin (take credit line, financing for leverage...).
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev Integrating this Account as means of margin/collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's Account functions will guarantee you a certain value of the Account.
 * For allowlists or liquidation strategies specific to your protocol, contact pragmalabs.dev
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
