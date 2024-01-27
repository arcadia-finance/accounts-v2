/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IRegistry } from "../../../../src/asset-modules/interfaces/IRegistry.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

/**
 * @title Asset Module for ERC721 tokens for which a oracle exists for the floor price of the collection
 * @author Pragma Labs
 * @notice The FloorERC721AM stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC721AM, only the Registry  or the contract owner
 */
contract FloorERC721AM is PrimaryAM {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => index range.
    mapping(address => IdRange) internal idRange;

    // Struct with additional information for a specific asset.
    struct IdRange {
        // The first index of the allowed range.
        uint256 start;
        // The last index of the allowed range.
        uint256 end;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error InvalidRange();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "1" for ERC721 tokens.
     */
    constructor(address registry_) PrimaryAM(registry_, 1) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC721AM.
     * @param asset The contract address of the asset
     * @param idRangeStart: The id of the first NFT of the collection
     * @param idRangeEnd: The id of the last NFT of the collection
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     */
    function addAsset(address asset, uint256 idRangeStart, uint256 idRangeEnd, bytes32 oracleSequence)
        external
        onlyOwner
    {
        if (idRangeStart > idRangeEnd) revert InvalidRange();
        if (!IRegistry(REGISTRY).checkOracleSequence(oracleSequence)) revert BadOracleSequence();
        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(asset);

        inAssetModule[asset] = true;

        // Unit for ERC721 is 1 (standard ERC721s don't have decimals).
        assetToInformation[_getKeyFromAsset(asset, 0)] =
            AssetInformation({ assetUnit: 1, oracleSequence: oracleSequence });
        idRange[asset] = IdRange({ start: idRangeStart, end: idRangeEnd });
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for an asset and the corresponding Id if it is allowed.
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (inAssetModule[asset]) {
            if (isIdInRange(asset, assetId)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Checks if the Id for a given token is in the range for which there exists a price feed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the Id of the given asset is in range.
     */
    function isIdInRange(address asset, uint256 assetId) internal view returns (bool) {
        if (assetId >= idRange[asset].start && assetId <= idRange[asset].end) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0.
     * Since all assets of the same ERC721 collection are floor NFTs, we only care about total exposures per collection,
     * not of individual ids.
     */
    function _getKeyFromAsset(address asset, uint256) internal pure override returns (bytes32 key) {
        assembly {
            key := asset
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The Id of the asset.
     * @dev The assetId is hard-coded to 0.
     * Since all assets of the same ERC721 collection are floor NFTs, we only care about total exposures per collection,
     * not of individual ids.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
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
     * @dev amount of a deposit in ERC721 asset module must be 1.
     * @dev super.processDirectDeposit checks that msg.sender is the Registry.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        returns (uint256, uint256)
    {
        if (!isAllowed(asset, assetId)) revert AssetNotAllowed();

        // Also checks that msg.sender == Registry.
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
     * @dev super.processIndirectDeposit checks that msg.sender is the Registry.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (uint256, uint256) {
        if (!isAllowed(asset, assetId)) revert AssetNotAllowed();

        // Also checks that msg.sender == Registry.
        return super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }
}
