/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { AssetModule } from "./AbstractAssetModule.sol";
import { RiskConstants } from "../libraries/RiskConstants.sol";

/**
 * @title Primary Asset Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a Primary Asset Module.
 * @dev Primary assets are assets with no underlying assets, that can be priced using external oracles.
 */
abstract contract PrimaryAssetModule is AssetModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier indicating that it is a Primary Asset Module:
    // the assets being priced have no underlying assets.
    bool internal constant PRIMARY_FLAG = true;

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
        uint128 lastExposureAsset;
        // The maximum exposure of a Creditor to an asset.
        uint128 maxExposure;
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
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event MaxExposureSet(address indexed asset, uint128 maxExposure);

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
     * @notice Sets a new oracle sequence in the case one of the current oracles is decommissioned.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param newOracles The new sequence of the oracles, to price the asset in USD,
     * packed in a single bytes32 object.
     */
    function setOracles(address asset, uint256 assetId, bytes32 newOracles) external onlyOwner {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Old oracles must be decommissioned before a new sequence can be set.
        bytes32 oldOracles = assetToInformation[assetKey].oracleSequence;
        if (IRegistry(REGISTRY).checkOracleSequence(oldOracles)) revert Oracle_Still_Active();

        // The new oracle sequence must be correct.
        if (!IRegistry(REGISTRY).checkOracleSequence(newOracles)) revert Bad_Oracle_Sequence();

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
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.x
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
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external onlyRegistry {
        if (collateralFactor > RiskConstants.RISK_FACTOR_UNIT) revert Coll_Factor_Not_In_Limits();
        if (liquidationFactor > RiskConstants.RISK_FACTOR_UNIT) revert Liq_Factor_Not_In_Limits();

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
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyRegistry
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        if (lastExposureAsset + amount >= riskParams[creditor][assetKey].maxExposure) revert Exposure_Not_In_Limits();

        unchecked {
            riskParams[creditor][assetKey].lastExposureAsset = uint128(lastExposureAsset + amount);
        }
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Asset Module.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        // Update lastExposureAsset.
        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = lastExposureAsset + uint256(deltaExposureUpperAssetToAsset);
        } else {
            exposureAsset = lastExposureAsset > uint256(-deltaExposureUpperAssetToAsset)
                ? lastExposureAsset - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        if (exposureAsset >= riskParams[creditor][assetKey].maxExposure) revert Exposure_Not_In_Limits();
        // unchecked cast: "RiskParameters.maxExposure" is a uint128.
        riskParams[creditor][assetKey].lastExposureAsset = uint128(exposureAsset);

        // Get Value in USD.
        (usdExposureUpperAssetToAsset,,) = getValue(creditor, asset, assetId, exposureUpperAssetToAsset);

        return (PRIMARY_FLAG, usdExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on a direct withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyRegistry
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        unchecked {
            lastExposureAsset >= amount
                ? riskParams[creditor][assetKey].lastExposureAsset = uint128(lastExposureAsset - amount)
                : riskParams[creditor][assetKey].lastExposureAsset = 0;
        }
    }

    /**
     * @notice Decreases the exposure to an asset on an indirect withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Asset Module.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache lastExposureAsset.
        uint256 lastExposureAsset = riskParams[creditor][assetKey].lastExposureAsset;

        uint256 exposureAsset;
        unchecked {
            if (deltaExposureUpperAssetToAsset > 0) {
                exposureAsset = lastExposureAsset + uint256(deltaExposureUpperAssetToAsset);
                if (exposureAsset > type(uint128).max) revert Overflow();
            } else {
                exposureAsset = lastExposureAsset > uint256(-deltaExposureUpperAssetToAsset)
                    ? lastExposureAsset - uint256(-deltaExposureUpperAssetToAsset)
                    : 0;
            }
        }
        riskParams[creditor][assetKey].lastExposureAsset = uint128(exposureAsset);

        // Get Value in USD.
        (usdExposureUpperAssetToAsset,,) = getValue(creditor, asset, assetId, exposureUpperAssetToAsset);

        return (PRIMARY_FLAG, usdExposureUpperAssetToAsset);
    }
}
