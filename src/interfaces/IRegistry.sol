/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../libraries/AssetValuationLib.sol";

interface IRegistry {
    /**
     * @notice Returns the Factory address.
     * @return factory The contract address of the Factory.
     */
    function FACTORY() external view returns (address);

    /**
     * @notice Checks if an asset is in the Registry.
     * @param asset The contract address of the asset.
     * @return boolean.
     */
    function inRegistry(address asset) external view returns (bool);

    /**
     * @notice Batch deposit multiple assets.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    function batchProcessDeposit(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external returns (uint256[] memory);

    /**
     * @notice Batch withdraw multiple assets.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    function batchProcessWithdrawal(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external returns (uint256[] memory);

    /**
     * @notice Calculates the combined value of a combination of assets, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return assetValue The combined value of the assets, denominated in BaseCurrency.
     */
    function getTotalValue(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256);

    /**
     * @notice Calculates the collateralValue of a combination of assets, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return collateralValue The collateral value of the assets, denominated in BaseCurrency.
     */
    function getCollateralValue(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256);

    /**
     * @notice Calculates the getLiquidationValue of a combination of assets, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return liquidationValue The liquidation value of the assets, denominated in BaseCurrency.
     */
    function getLiquidationValue(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256);

    /**
     * @notice Calculates the values per asset, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The array of values per assets, denominated in BaseCurrency.
     */
    function getValuesInBaseCurrency(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors);
}
