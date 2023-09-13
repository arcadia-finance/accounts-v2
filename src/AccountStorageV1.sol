/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/**
 * @title Acadia Vaults.
 * @author Pragma Labs
 * @notice Arcadia Vaults are smart contracts that act as onchain, decentralized and composable margin accounts.
 * They provide individuals, DAOs, and other protocols with a simple and flexible way to deposit and manage multiple assets as collateral.
 * The total combination of assets can be used as margin to back liabilities issued by any financial protocol (lending, leverage, futures...).
 * @dev Users can use this vault to deposit assets (ERC20, ERC721, ERC1155, ...).
 * The vault will denominate all the pooled assets into one baseCurrency (one unit of account, like usd or eth).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Users can use the single denominated value of all their assets to take margin (take credit line, financing for leverage...).
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev Integrating this vault as means of margin/collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's vault functions will guarantee you a certain value of the vault.
 * For allowlists or liquidation strategies specific to your protocol, contact pragmalabs.dev
 */
contract AccountStorageV1 {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag Indicating if a function is locked to protect against reentrancy.
    uint256 internal locked;
    // Flag that indicates if a trusted creditor is set.
    bool public isTrustedCreditorSet;
    // The contract address of the liquidator, address 0 if no trusted creditor is set.
    address public liquidator;
    // The estimated maximum cost to liquidate a Vault, will count as Used Margin when a trusted creditor is set.
    uint96 public fixedLiquidationCost;
    // The owner of the Vault.
    address public owner;
    // The contract address of the MainRegistry.
    address public registry;
    // The trusted creditor, address 0 if no trusted creditor is set.
    address public trustedCreditor;
    // The baseCurrency of the Vault in which all assets and liabilities are denominated.
    address public baseCurrency;

    // Array with all the contract address of ERC20 tokens in the vault.
    address[] public erc20Stored;
    // Array with all the contract address of ERC721 tokens in the vault.
    address[] public erc721Stored;
    // Array with all the contract address of ERC1155 tokens in the vault.
    address[] public erc1155Stored;
    // Array with all the corresponding id's for each ERC721 token in the vault.
    uint256[] public erc721TokenIds;
    // Array with all the corresponding id's for each ERC1155 token in the vault.
    uint256[] public erc1155TokenIds;

    // Map asset => balance.
    mapping(address => uint256) public erc20Balances;
    // Map asset => id => balance.
    mapping(address => mapping(uint256 => uint256)) public erc1155Balances;
    // Map owner => assetManager => flag.
    mapping(address => mapping(address => bool)) public isAssetManager;
}
