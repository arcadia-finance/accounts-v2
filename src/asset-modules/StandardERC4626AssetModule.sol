/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAssetModule, IRegistry } from "./AbstractDerivedAssetModule.sol";
import { IERC4626 } from "../interfaces/IERC4626.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../libraries/AssetValuationLib.sol";

/**
 * @title Sub-registry for Standard ERC4626 tokens
 * @author Pragma Labs
 * @notice The StandardERC4626Registry stores pricing logic and basic information for ERC4626 tokens for which the underlying assets have direct price feed.
 * @dev No end-user should directly interact with the StandardERC4626Registry, only the Registry or the contract owner
 */
contract StandardERC4626AssetModule is DerivedAssetModule {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The Unique identifiers of the underlying assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */
    error Underlying_Asset_Not_Allowed();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC20 tokens is 0.
     */
    constructor(address registry_) DerivedAssetModule(registry_, 0) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the ERC4626 TokenAssetModule.
     * @param asset The contract address of the asset
     */
    function addAsset(address asset) external onlyOwner {
        address underlyingAsset = address(IERC4626(asset).asset());

        if (!IRegistry(REGISTRY).isAllowed(underlyingAsset, 0)) revert Underlying_Asset_Not_Allowed();
        inAssetModule[asset] = true;

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(underlyingAsset, 0);
        assetToUnderlyingAssets[_getKeyFromAsset(asset, 0)] = underlyingAssets_;

        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(asset);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        if (inAssetModule[asset]) {
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
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Asset Modules are ERC20's.
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
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Asset Modules are ERC20's.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];

        if (underlyingAssetKeys.length == 0) {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited ERC4626.
            (address asset,) = _getAssetFromKey(assetKey);
            address underlyingAsset = address(IERC4626(asset).asset());

            underlyingAssetKeys = new bytes32[](1);
            underlyingAssetKeys[0] = _getKeyFromAsset(underlyingAsset, 0);
        }
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(address, bytes32 assetKey, uint256 assetAmount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (address asset,) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = IERC4626(asset).convertToAssets(assetAmount);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
