/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IRegistry } from "./../interfaces/IRegistry.sol";
import { AssetModule } from "./AbstractAM.sol";

/**
 * @title Primary Asset Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a Primary Asset Module.
 * @dev Primary assets are assets with no underlying assets, that can be priced using external oracles.
 */
abstract contract PrimaryAM is AssetModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The unit of the liquidation and collateral factors, 4 decimals precision.
    uint256 internal constant ONE_4 = 10_000;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map with the risk parameters of each asset for each Credit.
    mapping(address creditor => mapping(bytes32 assetKey => RiskParameters riskParameters)) public riskParams;

    // Map asset => assetInformation.
    mapping(bytes32 assetKey => AssetInformation) public assetToInformation;

    // Struct with the risk parameters of a specific asset for a specific Creditor.
    struct RiskParameters {
        // The exposure of a Creditor to an asset at its last interaction.
        uint112 lastExposureAsset;
        // The maximum exposure of a Creditor to an asset.
        uint112 maxExposure;
        // The collateral factor of the asset for the Creditor, 4 decimals precision.
        uint16 collateralFactor;
        // The liquidation factor of the asset for the Creditor, 4 decimals precision.
        uint16 liquidationFactor;
    }

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        // The unit of the asset, equal to 10^decimals.
        uint64 assetUnit;
        // The sequence of the oracles to price the asset in USD, packed in a single bytes32 object.
        bytes32 oracleSequence;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error BadOracleSequence();
    error CollFactorExceedsLiqFactor();
    error CollFactorNotInLimits();
    error LiqFactorNotInLimits();
    error OracleStillActive();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the Accounts.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * ...
     */
    constructor(address registry_, uint256 assetType_) AssetModule(registry_, assetType_) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a new oracle sequence in the case one of the current oracles is not active.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param newOracles The new sequence of the oracles, to price the asset in USD,
     * packed in a single bytes32 object.
     */
    function setOracles(address asset, uint256 assetId, bytes32 newOracles) external onlyOwner {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // At least one of the old oracles must be inactive before a new sequence can be set.
        bytes32 oldOracles = assetToInformation[assetKey].oracleSequence;
        if (IRegistry(REGISTRY).checkOracleSequence(oldOracles)) revert OracleStillActive();

        // The new oracle sequence must be correct.
        if (!IRegistry(REGISTRY).checkOracleSequence(newOracles)) revert BadOracleSequence();

        assetToInformation[assetKey].oracleSequence = newOracles;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param assetAmount The amount of assets.
     * @return valueInUsd The value of the asset denominated in USD, with 18 decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev If the asset is not added to AssetModule, this function will return value 0 without throwing an error.
     * However check in here is not necessary,
     * since the check if the asset is added to the AssetModule is already done in the Registry.
     */
    function getValue(address creditor, address asset, uint256 assetId, uint256 assetAmount)
        public
        view
        virtual
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        uint256 rateInUsd = IRegistry(REGISTRY).getRateInUsd(assetToInformation[assetKey].oracleSequence);
        valueInUsd = assetAmount.mulDivDown(rateInUsd, assetToInformation[assetKey].assetUnit);

        collateralFactor = riskParams[creditor][assetKey].collateralFactor;
        liquidationFactor = riskParams[creditor][assetKey].liquidationFactor;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK PARAMETER MANAGEMENT
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
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        collateralFactor = riskParams[creditor][assetKey].collateralFactor;
        liquidationFactor = riskParams[creditor][assetKey].liquidationFactor;
    }

    /**
     * @notice Sets the risk parameters for an asset for a given Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param maxExposure The maximum exposure of a Creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     */
    function setRiskParameters(
        address creditor,
        address asset,
        uint256 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external onlyRegistry {
        if (collateralFactor > ONE_4) revert CollFactorNotInLimits();
        if (liquidationFactor > ONE_4) revert LiqFactorNotInLimits();
        if (collateralFactor > liquidationFactor) revert CollFactorExceedsLiqFactor();

        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        riskParams[creditor][assetKey].maxExposure = maxExposure;
        riskParams[creditor][assetKey].collateralFactor = collateralFactor;
        riskParams[creditor][assetKey].liquidationFactor = liquidationFactor;
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on a direct deposit.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
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
        virtual
        override
        onlyRegistry
        returns (uint256, uint256)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        // The exposure must be strictly smaller than the maxExposure, not equal to or smaller than.
        // This is to ensure that all deposits revert when maxExposure is set to 0, also deposits with 0 amounts.
        if (lastExposureAsset + amount >= riskParams[creditor][assetKey].maxExposure) revert ExposureNotInLimits();

        unchecked {
            riskParams[creditor][assetKey].lastExposureAsset = uint112(lastExposureAsset + amount);
        }

        return (1, ASSET_TYPE);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     * @dev An indirect deposit is initiated by a deposit of a Derived Asset (the upper asset),
     * from which the asset of this Asset Module is an Underlying Asset.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        // Update lastExposureAsset.
        uint256 exposureAsset;
        unchecked {
            if (deltaExposureUpperAssetToAsset > 0) {
                exposureAsset = lastExposureAsset + uint256(deltaExposureUpperAssetToAsset);
            } else {
                exposureAsset = lastExposureAsset > uint256(-deltaExposureUpperAssetToAsset)
                    ? lastExposureAsset - uint256(-deltaExposureUpperAssetToAsset)
                    : 0;
            }
        }
        // The exposure must be strictly smaller than the maxExposure, not equal to or smaller than.
        // This is to ensure that all deposits revert when maxExposure is set to 0, also deposits with 0 amounts.
        if (exposureAsset >= riskParams[creditor][assetKey].maxExposure) revert ExposureNotInLimits();
        // unchecked cast: "RiskParameters.maxExposure" is a uint112.
        riskParams[creditor][assetKey].lastExposureAsset = uint112(exposureAsset);

        // Get Value in USD.
        (usdExposureUpperAssetToAsset,,) = getValue(creditor, asset, assetId, exposureUpperAssetToAsset);

        return (1, usdExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on a direct withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param amount The amount of tokens.
     * @return assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155
     * ...
     * @dev The checks on exposures are only done to block deposits that would over-expose a Creditor to a certain asset or protocol.
     * Underflows will not revert, but the exposure is instead set to 0.
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyRegistry
        returns (uint256 assetType)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        unchecked {
            lastExposureAsset >= amount
                ? riskParams[creditor][assetKey].lastExposureAsset = uint112(lastExposureAsset - amount)
                : riskParams[creditor][assetKey].lastExposureAsset = 0;
        }

        assetType = ASSET_TYPE;
    }

    /**
     * @notice Decreases the exposure to an asset on an indirect withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     * @dev An indirect withdrawal is initiated by a withdrawal of a Derived Asset (the upper asset),
     * from which the asset of this Asset Module is an Underlying Asset.
     * @dev The checks on exposures are only done to block deposits that would over-expose a Creditor to a certain asset or protocol.
     * Underflows will not revert, but the exposure is instead set to 0.
     * @dev Due to changing compositions of derived assets, exposure to a primary asset can increase or decrease over time,
     * independent of deposits/withdrawals.
     * When derived assets are deposited/withdrawn, these changes in composition since last interaction are also synced.
     * As such the actual exposure on an indirect withdrawal of a primary asset can exceed the maxExposure, but this should never be blocked,
     * (the withdrawal actually improves the situation by making the asset less over-exposed).
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        uint256 exposureAsset;
        unchecked {
            if (deltaExposureUpperAssetToAsset > 0) {
                exposureAsset = lastExposureAsset + uint256(deltaExposureUpperAssetToAsset);
                if (exposureAsset > type(uint112).max) revert Overflow();
            } else {
                exposureAsset = lastExposureAsset > uint256(-deltaExposureUpperAssetToAsset)
                    ? lastExposureAsset - uint256(-deltaExposureUpperAssetToAsset)
                    : 0;
            }
        }
        riskParams[creditor][assetKey].lastExposureAsset = uint112(exposureAsset);

        // Get Value in USD.
        (usdExposureUpperAssetToAsset,,) = getValue(creditor, asset, assetId, exposureUpperAssetToAsset);
    }
}
