/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import { IPricingModule } from "../../interfaces/IPricingModuleOptionThomas.sol";

interface IMainRegistry {
    /**
     * @notice Returns the number of baseCurrencies.
     * @return Counter for the number of baseCurrencies in use.
     */
    function baseCurrencyCounter() external view returns (uint256);

    /**
     * @notice Adds a new asset to the Main Registry.
     * @param asset The contract address of the asset.
     * @param assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    function addAsset(address asset, uint256 assetType) external;

    function getValueUnderlyingAsset(IPricingModule.GetValueInput memory getValueInput)
        external
        view
        returns (uint256, uint256, uint256);

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to increase the exposure of the underlying asset.
     * @param underlyingAsset The underlying asset of a non-primary asset.
     * @param exposureAssetToUnderlyingAsset.
     * @param deltaExposureAssetToUnderlyingAsset.
     */
    function getUsdExposureUnderlyingAssetAfterDeposit(
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external returns (uint256 usdValueExposureAssetToUnderlyingAsset);

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to decrease the exposure of the underlying asset.
     * @param underlyingAsset The underlying asset of a non-primary asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset.
     * @param deltaExposureAssetToUnderlyingAsset.
     */
    function getUsdExposureUnderlyingAssetAfterWithdrawal(
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external returns (uint256 usdValueExposureAssetToUnderlyingAsset);
}
