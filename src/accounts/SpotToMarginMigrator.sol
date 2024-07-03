/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IAccount } from "../interfaces/IAccount.sol";
import { IAccountSpot } from "../interfaces/IAccountSpot.sol";
import { IAccountV1 } from "../interfaces/IAccountV1.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { IFactory } from "../interfaces/IFactory.sol";
import { SafeTransferLib } from "../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title SpotToMarginMigrator.
 * @author Pragma Labs
 * @notice .
 */
contract SpotToMarginMigrator {
    using SafeTransferLib for IERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    address public immutable FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    mapping(address owner => address account) public accountOwnedBy;

    /* //////////////////////////////////////////////////////////////
                                 EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error NoAccountToTransfer();
    error NotOwner();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     */
    constructor(address factory) {
        FACTORY = factory;
    }

    /* //////////////////////////////////////////////////////////////
                               MIGRATION
    ////////////////////////////////////////////////////////////// */

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
        if (msg.sender != IAccountV1(account).owner()) revert NotOwner();
        // Transfer the Account
        IFactory(FACTORY).safeTransferFrom(msg.sender, address(this), account);
        // Withdraw assets from the account
        IAccountSpot(account).withdraw(assets, assetIds, assetAmounts, assetTypes);
        // Upgrade account
        IFactory(FACTORY).upgradeAccountVersion(account, newVersion, proofs);
        // Deposit assets in new Account version
        IAccountV1(account).deposit(assets, assetIds, assetAmounts);
        // Open margin account
        IAccountV1(account).openMarginAccount(creditor);
    }

    function endUpgrade() external {
        if (accountOwnedBy[msg.sender] == address(0)) revert NoAccountToTransfer();
        // Cache Acccount
        address account = accountOwnedBy[msg.sender];
        // Remove claimable account for owner
        accountOwnedBy[msg.sender] = address(0);
        // Transfer Account back to owner
        IFactory(FACTORY).safeTransferFrom(address(this), msg.sender, account);
    }
}
