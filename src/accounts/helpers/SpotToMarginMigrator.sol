/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { IAccount } from "../../interfaces/IAccount.sol";
import { IAccountSpot } from "../../interfaces/IAccountSpot.sol";
import { IAccountV1 } from "../../interfaces/IAccountV1.sol";
import { IERC1155 } from "../../interfaces/IERC1155.sol";
import { IERC721 } from "../../interfaces/IERC721.sol";
import { IFactory } from "../../interfaces/IFactory.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title SpotToMarginMigrator.
 * @author Pragma Labs
 * @notice This contracts acts as a facilitator to upgrade an Arcadia Spot Account to a Margin Account.
 * @notice The upgrade process consists of two steps. First, the Account owner must call upgradeAccount().
 * Second, after any cool-down period in the Spot Account, the owner must call endUpgrade() to receive their Margin Account back.
 */
contract SpotToMarginMigrator {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    IFactory public immutable FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    mapping(address owner => address account) internal accountOwnedBy;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error CreditorNotValid();
    error NoOngoingUpgrade();
    error NotOwner();
    error OngoingUpgrade();

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     */
    constructor(address factory) {
        FACTORY = IFactory(factory);
    }

    /* //////////////////////////////////////////////////////////////
                               MIGRATION
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will upgrade a Spot Account to a Margin Account.
     * @param account The Account to upgrade.
     * @param creditor The creditor that will be set on the Margin Account.
     * @param newVersion The Account Version of the Margin Account.
     * @param proofs The Merkle proofs that prove the compatibility of the upgrade from current to new account version.
     * @param assets The assets that needs to be withdrawn from the Spot Account and deposited in the Margin Account.
     * Only assets deposited via the deposit function in the Margin Account will be accounted as collateral.
     * @param assetIds The assetIds of respective assets to withdraw from Spot Account and Deposit in Margin Account.
     * @param assetAmounts The amount of respective assets to withdraw from Spot Account and Deposit in Margin Account.
     * @param assetTypes The asset types of respective assets to withdraw from Spot Account and Deposit in Margin Account.
     * @dev The upgrade is a two-step process. As withdraw function uses a cool-down period during which ownership cannot be transferred.
     * This prevents the old Owner from frontrunning a transferFrom().
     * User needs to call endUpgrade() after cool-down period to transfer the upgraded Margin Account to the user.
     */
    function upgradeAccount(
        address account,
        address creditor,
        uint256 newVersion,
        bytes32[] memory proofs,
        address[] memory assets,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes
    ) external {
        if (msg.sender != IAccountSpot(account).owner()) revert NotOwner();
        if (accountOwnedBy[msg.sender] != address(0)) revert OngoingUpgrade();
        if (creditor == address(0)) revert CreditorNotValid();
        // Transfer the Account
        FACTORY.safeTransferFrom(msg.sender, address(this), account);
        // Withdraw assets from the account
        IAccountSpot(account).withdraw(assets, assetIds, assetAmounts, assetTypes);
        // Upgrade account
        FACTORY.upgradeAccountVersion(account, newVersion, proofs);
        // Approve all assets to deposit in Account
        _approveAllAssets(account, assets, assetIds, assetAmounts, assetTypes);
        // Deposit assets in new Account version
        IAccountV1(account).deposit(assets, assetIds, assetAmounts);
        // Open margin account
        IAccountV1(account).openMarginAccount(creditor);
        // Keep track of the owner of the Account, mapping will be set to the zero address when upgrade is complete.
        accountOwnedBy[msg.sender] = account;
    }

    /**
     * @notice Call this function after the cool-down period of the initial Spot Account has passed (following upgradeAccount()).
     * This will finalize the upgrade and transfer the Margin Account to the caller.
     */
    function endUpgrade(address account) external {
        if (accountOwnedBy[msg.sender] == address(0)) revert NoOngoingUpgrade();
        // Cache Acccount
        address account = accountOwnedBy[msg.sender];
        // Remove claimable account for owner
        accountOwnedBy[msg.sender] = address(0);
        // Transfer Account back to owner
        FACTORY.safeTransferFrom(address(this), msg.sender, account);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice This internal function approves all assets that needs to be deposited in the Account on an upgrade.
     * @param account The Account to upgrade.
     * @param assets The assets to approve for deposit in the Account.
     * @param assetIds The assetIds of respective assets to approve.
     * @param assetAmounts The amount of respective assets to approve.
     * @param assetTypes The asset types of respective assets to approve.
     * @dev The same data is used for withdrawal from the Spot Account and deposit into the Margin Account.
     * This approach eliminates the risk of leftover assets that could potentially be taken advantage of during subsequent Account upgrades.
     */
    function _approveAllAssets(
        address account,
        address[] memory assets,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes
    ) internal {
        for (uint256 i; i < assets.length; ++i) {
            // Skip if amount is 0, no approval needed.
            if (assetAmounts[i] == 0) continue;
            if (assetTypes[i] == 1) {
                ERC20(assets[i]).safeApprove(account, assetAmounts[i]);
            } else if (assetTypes[i] == 2) {
                IERC721(assets[i]).approve(account, assetIds[i]);
            } else if (assetTypes[i] == 3) {
                IERC1155(assets[i]).setApprovalForAll(account, true);
            }
        }
    }

    /* 
    @notice Returns the onERC721Received selector.
    @dev Needed to receive ERC721 tokens.
    */
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*
    @notice Returns the onERC1155Received selector.
    @dev Needed to receive ERC1155 tokens.
    */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
