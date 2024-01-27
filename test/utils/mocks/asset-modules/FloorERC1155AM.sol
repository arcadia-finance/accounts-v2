/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IRegistry } from "../../../../src/asset-modules/interfaces/IRegistry.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

/**
 * @title Asset Module for ERC1155 tokens
 * @author Pragma Labs
 * @notice The FloorERC1155AM stores pricing logic and basic information for ERC1155 tokens,
 *  for which a direct price feed exists per Id.
 * @dev No end-user should directly interact with the FloorERC1155AM, only the Registry or the contract owner
 */
contract FloorERC1155AM is PrimaryAM {
    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAlreadyInAM();
    error AssetNotAllowed();
    error InvalidId();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for ERC1155 tokens.
     */
    constructor(address registry_) PrimaryAM(registry_, 2) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC1155AM.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     */
    function addAsset(address asset, uint256 assetId, bytes32 oracleSequence) external onlyOwner {
        if (inAssetModule[asset]) {
            // Contract address already added -> must be a new Id.
            if (assetToInformation[_getKeyFromAsset(asset, assetId)].assetUnit != 0) revert AssetAlreadyInAM();
        } else {
            // New contract address.
            IRegistry(REGISTRY).addAsset(asset);
            inAssetModule[asset] = true;
        }
        if (assetId > type(uint96).max) revert InvalidId();
        if (!IRegistry(REGISTRY).checkOracleSequence(oracleSequence)) revert BadOracleSequence();

        // Unit for ERC1155 is 1 (standard ERC1155s don't have decimals).
        assetToInformation[_getKeyFromAsset(asset, assetId)] =
            AssetInformation({ assetUnit: 1, oracleSequence: oracleSequence });
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset passed as input is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (assetToInformation[_getKeyFromAsset(asset, assetId)].assetUnit == 1) return true;

        return false;
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on a direct deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @return assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155
     * ...
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        onlyRegistry
        returns (uint256, uint256)
    {
        if (!isAllowed(asset, assetId)) revert AssetNotAllowed();

        return super.processDirectDeposit(creditor, asset, assetId, amount);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @return usdExposureUpperAssetToAsset The Usd value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyRegistry returns (uint256, uint256) {
        if (!isAllowed(asset, assetId)) revert AssetNotAllowed();

        return super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }
}
