/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DerivedPricingModule } from "./AbstractDerivedPricingModule.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IERC4626 } from "../interfaces/IERC4626.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IStandardERC20PricingModule } from "./interfaces/IStandardERC20PricingModule.sol";

/**
 * @title Sub-registry for Standard ERC4626 tokens
 * @author Pragma Labs
 * @notice The StandardERC4626Registry stores pricing logic and basic information for ERC4626 tokens for which the underlying assets have direct price feed.
 * @dev No end-user should directly interact with the StandardERC4626Registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract StandardERC4626PricingModule is DerivedPricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The Unique identifiers of the underlying assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub.
     * @param mainRegistry_ The address of the Main-registry.
     * @param oracleHub_ The address of the Oracle-Hub.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC20 tokens is 0.
     */
    constructor(address mainRegistry_, address oracleHub_)
        DerivedPricingModule(mainRegistry_, oracleHub_, 0, msg.sender)
    { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the ERC4626 TokenPricingModule.
     * @param asset The contract address of the asset
     */
    function addAsset(address asset) external onlyOwner {
        address underlyingAsset = address(IERC4626(asset).asset());

        require(IMainRegistry(MAIN_REGISTRY).isAllowed(underlyingAsset, 0), "PM4626_AA: Underlying Asset not allowed");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(underlyingAsset, 0);
        assetToUnderlyingAssets[_getKeyFromAsset(asset, 0)] = underlyingAssets_;

        // Will revert in MainRegistry if pool was already added.
        IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);
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
        if (inPricingModule[asset]) {
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
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Pricing Modules are ERC20's.
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
     * @dev The assetId is hard-coded to 0, since both the assets as underlying assets for this Pricing Modules are ERC20's.
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
     * @return underlyingAssetKeys The assets to which we have to get the conversion rate.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];

        if (underlyingAssetKeys.length == 0) {
            // Only used as an off-chain view function to return the value of a non deposited Liquidity Position.
            (address asset,) = _getAssetFromKey(assetKey);
            address underlyingAsset = address(IERC4626(asset).asset());

            underlyingAssetKeys = new bytes32[](1);
            underlyingAssetKeys[0] = _getKeyFromAsset(underlyingAsset, 0);
        }
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(bytes32 assetKey, uint256 assetAmount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, uint256[] memory rateUnderlyingAssetsToUsd)
    {
        (address asset,) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = IERC4626(asset).convertToAssets(assetAmount);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
