/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface ITrustedCreditor {
    /**
     * @notice Checks if account fulfills all requirements and returns application settings.
     * @param accountVersion The current version of the Account.
     * @return success Bool indicating if all requirements are met.
     * @return baseCurrency The base currency of the application.
     * @return liquidator The liquidator of the application.
     * @return fixedLiquidationCost Estimated fixed costs (independent of size of debt) to liquidate a position.
     */
    function openMarginAccount(uint256 accountVersion) external view returns (bool, address, address, uint256);

    /**
     * @notice Returns the open position of the Account.
     * @param account The account address.
     * @return openPosition The open position of the Account.
     */
    function getOpenPosition(address account) external view returns (uint256);

    /**
     * @notice Returns the Risk Manager of the creditor.
     * @return riskManager The Risk Manager of the creditor.
     */
    function riskManager() external view returns (address riskManager);

    /**
     * @notice Starts the liquidation of an account and returns the open position of the Account.
     * @param account The account address.
     * @return openPosition the open position of the Account
     */
    function startLiquidation(address account) external view returns (uint256);
}
