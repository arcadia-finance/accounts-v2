/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

interface ILendingPool {
    /**
     * @notice Enables or disables a certain Account version to be used as margin account.
     * @param accountVersion the Account version to be enabled/disabled.
     * @param valid The validity of the respective accountVersion.
     */
    function setAccountVersion(uint256 accountVersion, bool valid) external;

    /**
     * @notice Sets a new Risk Manager.
     * @param riskManager The address of the new Risk Manager.
     */
    function setRiskManager(address riskManager) external;

    /**
     * @notice Gets the validity of a certain Account version.
     * @param accountVersion The Account version to be checked.
     * @return valid The validity of the respective accountVersion.
     */
    function isValidVersion(uint256 accountVersion) external view returns (bool);

    /**
     * @notice Gets the Risk Manager of the pool.
     * @return riskManager The Risk Manager of the pool.
     */
    function riskManager() external view returns (address);
}
