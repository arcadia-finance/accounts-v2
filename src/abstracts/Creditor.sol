/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ICreditor } from "../interfaces/ICreditor.sol";

/**
 * @title Creditor.
 * @author Pragma Labs
 * @notice See the documentation in ICreditor
 */
abstract contract Creditor is ICreditor {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The address of the riskManager.
    address public riskManager;

    // The Account for which a flashAction is called.
    address internal callbackAccount;

    // Map accountVersion => status.
    mapping(uint256 => bool) public isValidVersion;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RiskManagerUpdated(address riskManager);
    event ValidAccountVersionsUpdated(uint256 indexed accountVersion, bool valid);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    // Thrown when caller is not authorized.
    error Unauthorized();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param riskManager_ The address of the Risk Manager.
     */
    constructor(address riskManager_) {
        _setRiskManager(riskManager_);
    }

    /* //////////////////////////////////////////////////////////////
                            ACCOUNT LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets a new Risk Manager. A Risk Manager can:
     * - Set risk parameters for collateral assets, including: max exposures, collateral factors and liquidation factors.
     * - Set minimum usd values for assets in order to be taken into account, to prevent dust attacks.
     * @param riskManager_ The address of the new Risk Manager.
     */
    function _setRiskManager(address riskManager_) internal {
        riskManager = riskManager_;

        emit RiskManagerUpdated(riskManager_);
    }

    /**
     * @notice Updates the validity of an Account version.
     * @param accountVersion The Account version.
     * @param isValid Will be "true" if respective Account version is valid, "false" if not.
     */
    function _setAccountVersion(uint256 accountVersion, bool isValid) internal {
        isValidVersion[accountVersion] = isValid;

        emit ValidAccountVersionsUpdated(accountVersion, isValid);
    }

    /**
     * @inheritdoc ICreditor
     * @dev This function response is used for the Arcadia Accounts margin account creation.
     * This function does not deploy a new Arcadia Account.
     * It just provides the parameters to be used in Arcadia Account to connect to the Creditor.
     */
    function openMarginAccount(uint256 accountVersion)
        external
        virtual
        returns (bool success, address numeraire, address liquidator, uint256 minimumMargin);

    /**
     * @inheritdoc ICreditor
     * @dev This function checks if the given Account address has an open position. If not, it can be closed.
     */
    function closeMarginAccount(address account) external virtual;

    /**
     * @inheritdoc ICreditor
     * @dev The open position is the sum of all liabilities.
     */
    function getOpenPosition(address account) external view virtual returns (uint256 openPosition);

    /**
     * @inheritdoc ICreditor
     * @dev During the callback, the Account cannot be reentered and the actionTimestamp is updated.
     */
    function flashActionCallback(bytes calldata callbackData) external virtual {
        // Only the Account for which the flashAction is initiated is allowed to callback.
        if (callbackAccount != msg.sender) revert Unauthorized();

        // Reset callbackAccount, the Account should only callback once during a flashAction.
        callbackAccount = address(0);

        _flashActionCallback(msg.sender, callbackData);
    }

    /**
     * @notice Callback of the Account during a flashAction.
     * @param account The contract address of the Arcadia Account.
     * @param callbackData The data for the actions that have to be executed by the Creditor during a flashAction.
     * @dev During the callback, the Account cannot be reentered and the actionTimestamp is updated.
     */
    function _flashActionCallback(address account, bytes calldata callbackData) internal virtual;

    /**
     * @inheritdoc ICreditor
     * @dev Starts the liquidation process in the Creditor.
     * This function should be callable by Arcadia Account.
     */
    function startLiquidation(address initiator, uint256 minimumMargin)
        external
        virtual
        returns (uint256 openPosition);
}
