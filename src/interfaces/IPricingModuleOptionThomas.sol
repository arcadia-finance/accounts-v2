/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IPricingModule {
    // A Struct with the input variables for the function getValue() (avoid stack to deep).
    struct GetValueInput {
        address asset; // The contract address of the asset.
        uint256 assetId; // The Id of the asset.
        uint256 assetAmount; // The amount of assets.
        uint256 baseCurrency; // Identifier of the BaseCurrency.
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency.
     * @param input A Struct with the input variables (avoid stack to deep).
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     */
    function getValue(GetValueInput memory input) external view returns (uint256, uint256, uint256);

    /**
     * @notice Returns the risk variables of an asset.
     * @param asset The contract address of the asset.
     * @param baseCurrency An identifier (uint256) of the BaseCurrency.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, 2 decimals precision.
     */
    function getRiskVariables(address asset, uint256 baseCurrency) external view returns (uint16, uint16);

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * @param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address asset, uint256 id, uint256 amount) external;

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * @param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processIndirectDeposit(address asset, uint256 id, int256 amount) external returns (bool, uint256);

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectWithdrawal(address asset, uint256 id, uint256 amount) external;

    /**
     * @notice Decreases the exposure to an underlying asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processIndirectWithdrawal(address asset, uint256 id, int256 amount) external returns (bool, uint256);
}
