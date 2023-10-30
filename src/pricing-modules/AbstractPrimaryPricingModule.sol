/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { PricingModule, IPricingModule } from "./AbstractPricingModule.sol";

/**
 * @title Primary Pricing Module.
 * @author Pragma Labs
 */
abstract contract PrimaryPricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier indicating that it is a Primary Pricing Module:
    // the assets being priced have no underlying assets.
    bool internal constant PRIMARY_FLAG = true;

    // The maximum collateral factor of an asset for a creditor, 2 decimals precision.
    uint16 internal constant MAX_COLLATERAL_FACTOR = 100;
    // The maximum liquidation factor of an asset for a creditor, 2 decimals precision.
    uint16 internal constant MAX_LIQUIDATION_FACTOR = 100;

    // The contract address of the OracleHub.
    address public immutable ORACLE_HUB;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map with the risk parameters of each asset for each creditor.
    mapping(address creditor => mapping(bytes32 assetKey => RiskParameters riskParameters)) public riskParams;

    // Struct with the risk parameters of a specific asset for a specific creditor.
    struct RiskParameters {
        uint128 exposureLast; // The exposure of a creditor to an asset at its last interaction.
        uint128 maxExposure; // The maximum exposure of a creditor to an asset.
        uint16 collateralFactor; // The collateral factor of the asset for the creditor, 2 decimals precision.
        uint16 liquidationFactor; // The liquidation factor of the asset for the creditor, 2 decimals precision.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event MaxExposureSet(address indexed asset, uint128 maxExposure);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The address of the Main-registry.
     * @param oracleHub_ The address of the Oracle-Hub.
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the Accounts.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        PricingModule(mainRegistry_, assetType_)
    {
        ORACLE_HUB = oracleHub_;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK PARAMETER MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors of an asset for a creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return collateralFactor The collateral factor of the asset for the creditor, 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the creditor, 2 decimals precision.
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
     * @notice Sets the risk parameters for an asset for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param maxExposure The maximum exposure of a creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the creditor, 2 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the creditor, 2 decimals precision.
     */
    function setRiskParameters(
        address creditor,
        address asset,
        uint256 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external onlyMainReg {
        require(collateralFactor <= MAX_COLLATERAL_FACTOR, "APPM_SRP: Coll.Fact not in limits");
        require(liquidationFactor <= MAX_LIQUIDATION_FACTOR, "APPM_SRP: Liq.Fact not in limits");

        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        riskParams[creditor][assetKey].maxExposure = maxExposure;
        riskParams[creditor][assetKey].collateralFactor = collateralFactor;
        riskParams[creditor][assetKey].liquidationFactor = liquidationFactor;
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyMainReg
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = riskParams[creditor][assetKey].exposureLast;

        require(exposureLast + amount <= riskParams[creditor][assetKey].maxExposure, "APPM_PDD: Exposure not in limits");

        unchecked {
            riskParams[creditor][assetKey].exposureLast = uint128(exposureLast) + uint128(amount);
        }
    }

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = riskParams[creditor][assetKey].exposureLast;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= riskParams[creditor][assetKey].maxExposure, "APPM_PID: Exposure not in limits");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        riskParams[creditor][assetKey].exposureLast = uint128(exposureAsset);

        // Get Value in Usd
        (usdValueExposureUpperAssetToAsset,,) = getValue(
            IPricingModule.GetValueInput({
                asset: asset,
                assetId: assetId,
                assetAmount: exposureUpperAssetToAsset,
                creditor: creditor
            })
        );

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @dev Unsafe cast to uint128, it is assumed no more than 10**(20+decimals) tokens will ever be deposited.
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyMainReg
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = riskParams[creditor][assetKey].exposureLast;

        exposureLast >= amount
            ? riskParams[creditor][assetKey].exposureLast = uint128(exposureLast) - uint128(amount)
            : riskParams[creditor][assetKey].exposureLast = 0;

        emit AssetExposureChanged(asset, uint128(exposureLast), riskParams[creditor][assetKey].exposureLast);
    }

    /**
     * @notice Decreases the exposure to an underlying asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = riskParams[creditor][assetKey].exposureLast;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= type(uint128).max, "APPM_PIW: Overflow");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        riskParams[creditor][assetKey].exposureLast = uint128(exposureAsset);

        emit AssetExposureChanged(asset, uint128(exposureLast), uint128(exposureAsset));

        // Get Value in Usd
        (usdValueExposureUpperAssetToAsset,,) = getValue(
            IPricingModule.GetValueInput({
                asset: asset,
                assetId: assetId,
                assetAmount: exposureUpperAssetToAsset,
                creditor: creditor
            })
        );

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }
}
