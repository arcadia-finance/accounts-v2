/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAssetModule.sol";
import { IPool } from "./interfaces/IPool.sol";
import { ISGFactory } from "./interfaces/ISGFactory.sol";

/**
 * @title Asset Module for non-staked Stargate Finance pools
 * @author Pragma Labs
 * @notice The Stargate Asset Module stores pricing logic and basic information for Stargate Finance LP pools
 * @dev No end-user should directly interact with the Stargate Asset Module, only the Registry, the contract owner or via the actionHandler
 */
contract StargateAM is DerivedAssetModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The Stargate Factory.
    ISGFactory public immutable SG_FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The unique identifiers of the underlying assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InvalidPool();
    error UnderlyingAssetNotAllowed();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param stargateFactory The factory for Stargate Pools.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "0" for ERC20 tokens.
     */
    constructor(address registry_, address stargateFactory) DerivedAssetModule(registry_, 0) {
        SG_FACTORY = ISGFactory(stargateFactory);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Stargate Pool to the StargateAssetModule.
     * @param poolId The id of the stargatePool used in the LP_STAKING_TIME contract.
     */
    function addAsset(uint256 poolId) external {
        address asset = address(SG_FACTORY.getPool(poolId));
        if (asset == address(0)) revert InvalidPool();

        address underlyingAsset = IPool(asset).token();
        if (!IRegistry(REGISTRY).isAllowed(underlyingAsset, 0)) revert UnderlyingAssetNotAllowed();

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
     * @return allowed A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool allowed) {
        if (inAssetModule[asset]) allowed = true;
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
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the Asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(address, bytes32 assetKey, uint256 amount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (address asset,) = _getAssetFromKey(assetKey);

        // "amountLPtoLD()" converts an amount of LP tokens into the corresponding amount of underlying tokens (LD stands for Local Decimals).
        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = IPool(asset).amountLPtoLD(amount);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
