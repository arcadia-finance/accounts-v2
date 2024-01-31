/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DerivedAM, FixedPointMathLib, IRegistry } from "../abstracts/AbstractDerivedAM.sol";
import { IPool } from "./interfaces/IPool.sol";
import { ISGFactory } from "./interfaces/ISGFactory.sol";

/**
 * @title Asset Module for non-staked Stargate Finance pools
 * @author Pragma Labs
 * @notice The Stargate Asset Module stores pricing logic and basic information for Stargate Finance LP pools
 * @dev No end-user should directly interact with the Stargate Asset Module, only the Registry, the contract owner or via the actionHandler
 */
contract StargateAM is DerivedAM {
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
    constructor(address registry_, address stargateFactory) DerivedAM(registry_, 0) {
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

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors of an asset for a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(_getKeyFromAsset(asset, assetId));

        address[] memory assets = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        (assets[0], assetIds[0]) = _getAssetFromKey(underlyingAssetKeys[0]);

        (uint16[] memory collateralFactors, uint16[] memory liquidationFactors) =
            IRegistry(REGISTRY).getRiskFactors(creditor, assets, assetIds);

        // Cache riskFactor
        uint256 riskFactor = riskParams[creditor].riskFactor;

        // Lower risk factors with the protocol wide risk factor.
        collateralFactor = uint16(riskFactor.mulDivDown(collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactor = uint16(riskFactor.mulDivDown(liquidationFactors[0], AssetValuationLib.ONE_4));
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) internal view override returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        // Initialize variables with first elements of array.
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        valueInUsd = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18);

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;
        collateralFactor = riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[0].collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor =
            riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[0].liquidationFactor, AssetValuationLib.ONE_4);
    }
}
