/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { AssetModule } from "./AbstractAssetModule.sol";
import { RiskConstants } from "../libraries/RiskConstants.sol";
import { RiskModule } from "../RiskModule.sol";

/**
 * @title Derived Asset Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a Derived Asset Module.
 * @dev Derived assets are assets with underlying assets, the underlying assets can be Primary Assets or also Derived assets.
 * For Derived assets there are are no direct external oracles.
 * USD-values of assets must be calculated in a recursive manner via the pricing logic of the Underlying Assets.
 */
abstract contract DerivedAssetModule is AssetModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier indicating that it is a Derived Asset Module.
    bool internal constant PRIMARY_FLAG = false;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map with the risk parameters of the protocol for each creditor.
    mapping(address creditor => RiskParameters riskParameters) public riskParams;
    // Map with the last exposures of each asset for each creditor.
    mapping(address creditor => mapping(bytes32 assetKey => ExposuresPerAsset)) internal lastExposuresAsset;
    // Map with the last amount of exposure of each underlying asset for each asset for each creditor.
    mapping(address creditor => mapping(bytes32 assetKey => mapping(bytes32 underlyingAssetKey => uint256 exposure)))
        internal lastExposureAssetToUnderlyingAsset;

    // Struct with the risk parameters of the protocol for a specific creditor.
    struct RiskParameters {
        // The exposure in usd of the creditor to the protocol at the last interaction, 18 decimals precision.
        uint128 lastUsdExposureProtocol;
        // The maximum exposure in usd of the creditor to the protocol, 18 decimals precision.
        uint128 maxUsdExposureProtocol;
        // The risk factor of the protocol for a creditor, 4 decimals precision.
        uint16 riskFactor;
    }

    // Struct with the exposures of a specific asset for a specific creditor.
    struct ExposuresPerAsset {
        // The amount of exposure of the creditor to the asset at the last interaction.
        uint128 lastExposureAsset;
        // The exposure in usd of the creditor to the asset at the last interaction, 18 decimals precision.
        uint128 lastUsdExposureAsset;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    constructor(address registry_, uint256 assetType_) AssetModule(registry_, assetType_) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        virtual
        returns (bytes32[] memory underlyingAssetKeys);

    /**
     * @notice Calculates the usd-rate of 10**18 underlying assets.
     * @param creditor The contract address of the creditor.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        internal
        view
        virtual
        returns (RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        uint256 length = underlyingAssetKeys.length;

        address[] memory underlyingAssets = new address[](length);
        uint256[] memory underlyingAssetIds = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);
        for (uint256 i; i < length;) {
            (underlyingAssets[i], underlyingAssetIds[i]) = _getAssetFromKey(underlyingAssetKeys[i]);
            // We use the USD price per 10^18 tokens instead of the USD price per token to guarantee
            // sufficient precision.
            amounts[i] = 1e18;

            unchecked {
                ++i;
            }
        }

        rateUnderlyingAssetsToUsd =
            IRegistry(REGISTRY).getValuesInUsd(creditor, underlyingAssets, underlyingAssetIds, amounts);
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 assetAmount,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        virtual
        returns (
            uint256[] memory underlyingAssetsAmounts,
            RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        );

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors of an asset for a creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return collateralFactor The collateral factor of the asset for the creditor, 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        virtual
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(_getKeyFromAsset(asset, assetId));

        uint256 length = underlyingAssetKeys.length;
        address[] memory assets = new address[](length);
        uint256[] memory assetIds = new uint256[](length);
        for (uint256 i; i < length;) {
            (assets[i], assetIds[i]) = _getAssetFromKey(underlyingAssetKeys[i]);

            unchecked {
                ++i;
            }
        }

        (uint16[] memory collateralFactors, uint16[] memory liquidationFactors) =
            IRegistry(REGISTRY).getRiskFactors(creditor, assets, assetIds);

        // Initialize risk factors with first elements of array.
        collateralFactor = collateralFactors[0];
        liquidationFactor = liquidationFactors[0];

        // Keep the lowest risk factor of all underlying assets.
        for (uint256 i = 1; i < length;) {
            if (collateralFactor > collateralFactors[i]) collateralFactor = collateralFactors[i];

            if (liquidationFactor > liquidationFactors[i]) liquidationFactor = liquidationFactors[i];

            unchecked {
                ++i;
            }
        }

        // Lower risk factors with the protocol wide risk factor.
        collateralFactor = uint16(
            FixedPointMathLib.mulDivDown(
                collateralFactor, riskParams[creditor].riskFactor, RiskConstants.RISK_FACTOR_UNIT
            )
        );
        liquidationFactor = uint16(
            FixedPointMathLib.mulDivDown(
                liquidationFactor, riskParams[creditor].riskFactor, RiskConstants.RISK_FACTOR_UNIT
            )
        );
    }

    /**
     * @notice Sets the risk parameters of the Protocol for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param maxUsdExposureProtocol_ The maximum usd exposure of the protocol for each creditor, denominated in USD with 18 decimals precision.
     * @param riskFactor The risk factor of the asset for the creditor, 4 decimals precision.
     */
    function setRiskParameters(address creditor, uint128 maxUsdExposureProtocol_, uint16 riskFactor)
        external
        onlyRegistry
    {
        if (riskFactor > RiskConstants.RISK_FACTOR_UNIT) revert AssetModule.Risk_Factor_Not_In_Limits();

        riskParams[creditor].maxUsdExposureProtocol = maxUsdExposureProtocol_;
        riskParams[creditor].riskFactor = riskFactor;
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param assetAmount The amount of assets.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given creditor, with 4 decimals precision.
     */
    function getValue(address creditor, address asset, uint256 assetId, uint256 assetAmount)
        public
        view
        virtual
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        (
            uint256[] memory underlyingAssetsAmounts,
            RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        ) = _getUnderlyingAssetsAmounts(creditor, assetKey, assetAmount, underlyingAssetKeys);

        // Check if rateToUsd for the underlying assets was already calculated in _getUnderlyingAssetsAmounts().
        if (rateUnderlyingAssetsToUsd.length == 0) {
            // If not, get the usd value of the underlying assets recursively.
            rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
        }

        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /**
     * @notice Returns the usd value of an asset.
     * @param creditor The contract address of the creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given creditor, with 4 decimals precision.
     * @dev We take the most conservative (lowest) risk factor of all underlying assets.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) internal view virtual returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        // Initialize variables with first elements of array.
        // "rateUnderlyingAssetsToUsd" is the usd value with 18 decimals precision for 10 ** 18 tokens of Underlying Asset.
        // To get the usd value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        valueInUsd =
            FixedPointMathLib.mulDivDown(underlyingAssetsAmounts[0], rateUnderlyingAssetsToUsd[0].assetValue, 1e18);
        collateralFactor = rateUnderlyingAssetsToUsd[0].collateralFactor;
        liquidationFactor = rateUnderlyingAssetsToUsd[0].liquidationFactor;

        // Update variables with elements from index 1 until end of arrays:
        //  - Add Usd value of all underlying assets together.
        //  - Keep the lowest risk factor of all underlying assets.
        uint256 length = underlyingAssetsAmounts.length;
        for (uint256 i = 1; i < length;) {
            valueInUsd +=
                FixedPointMathLib.mulDivDown(underlyingAssetsAmounts[i], rateUnderlyingAssetsToUsd[i].assetValue, 1e18);

            if (collateralFactor > rateUnderlyingAssetsToUsd[i].collateralFactor) {
                collateralFactor = rateUnderlyingAssetsToUsd[i].collateralFactor;
            }

            if (liquidationFactor > rateUnderlyingAssetsToUsd[i].liquidationFactor) {
                liquidationFactor = rateUnderlyingAssetsToUsd[i].liquidationFactor;
            }

            unchecked {
                ++i;
            }
        }

        // Lower risk factors with the protocol wide risk factor.
        collateralFactor = FixedPointMathLib.mulDivDown(
            collateralFactor, riskParams[creditor].riskFactor, RiskConstants.RISK_FACTOR_UNIT
        );
        liquidationFactor = FixedPointMathLib.mulDivDown(
            liquidationFactor, riskParams[creditor].riskFactor, RiskConstants.RISK_FACTOR_UNIT
        );
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
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyRegistry
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, int256(amount));

        _processDeposit(creditor, assetKey, exposureAsset);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Asset Module.
     * @return usdExposureUpperAssetToAsset The Usd value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, deltaExposureUpperAssetToAsset);

        uint256 usdExposureAsset = _processDeposit(creditor, assetKey, exposureAsset);

        if (exposureAsset == 0 || usdExposureAsset == 0) {
            usdExposureUpperAssetToAsset = 0;
        } else {
            // Calculate the USD value of the exposure of the upper asset to the underlying asset.
            usdExposureUpperAssetToAsset = usdExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);
        }

        return (PRIMARY_FLAG, usdExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on a direct withdrawal.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyRegistry
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, -int256(amount));

        _processWithdrawal(creditor, assetKey, exposureAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on an indirect withdrawal.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Asset Module.
     * @return usdExposureUpperAssetToAsset The Usd value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, deltaExposureUpperAssetToAsset);

        uint256 usdExposureAsset = _processWithdrawal(creditor, assetKey, exposureAsset);

        if (exposureAsset == 0 || usdExposureAsset == 0) {
            usdExposureUpperAssetToAsset = 0;
        } else {
            // Calculate the USD value of the exposure of the Upper Asset to the Underlying asset.
            usdExposureUpperAssetToAsset = usdExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);
        }

        return (PRIMARY_FLAG, usdExposureUpperAssetToAsset);
    }

    /**
     * @notice Update the exposure to an asset and it's underlying asset(s) on deposit.
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
     * @return usdExposureAsset The Usd value of the exposure of the asset, 18 decimals precision.
     */
    function _processDeposit(address creditor, bytes32 assetKey, uint256 exposureAsset)
        internal
        virtual
        returns (uint256 usdExposureAsset)
    {
        // Get the unique identifier(s) of the underlying asset(s).
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        // Get the exposure to the asset's underlying asset(s) (in the decimal precision of the underlying assets).
        (uint256[] memory exposureAssetToUnderlyingAssets,) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);

        int256 deltaExposureAssetToUnderlyingAsset;
        uint256 length = underlyingAssetKeys.length;
        for (uint256 i; i < length;) {
            // Calculate the change in exposure to the underlying assets since last interaction.
            deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAssets[i])
                - int256(uint256(lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]]));

            // Update "lastExposureAssetToUnderlyingAsset".
            lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]] =
                uint128(exposureAssetToUnderlyingAssets[i]); // ToDo: safecast?

            // Get the USD Value of the total exposure of "Asset" for its "Underlying Assets" at index "i".
            // If the "underlyingAsset" has one or more underlying assets itself, the lower level
            // Asset Module(s) will recursively update their respective exposures and return
            // the requested USD value to this Asset Module.
            (address underlyingAsset, uint256 underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdExposureAsset += IRegistry(REGISTRY).getUsdValueExposureToUnderlyingAssetAfterDeposit(
                creditor,
                underlyingAsset,
                underlyingId,
                exposureAssetToUnderlyingAssets[i],
                deltaExposureAssetToUnderlyingAsset
            );

            unchecked {
                ++i;
            }
        }

        // Cache and update lastUsdExposureAsset.
        uint256 lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
        lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = uint128(usdExposureAsset);

        // Cache lastUsdExposureProtocol.
        uint256 lastUsdExposureProtocol = riskParams[creditor].lastUsdExposureProtocol;

        // Update lastUsdExposureProtocol.
        uint256 usdExposureProtocol;
        unchecked {
            if (usdExposureAsset >= lastUsdExposureAsset) {
                usdExposureProtocol = lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset);
            } else if (lastUsdExposureProtocol > lastUsdExposureAsset - usdExposureAsset) {
                usdExposureProtocol = lastUsdExposureProtocol - (lastUsdExposureAsset - usdExposureAsset);
            }
            // If (lastUsdExposureProtocol < lastUsdExposureAsset - usdExposureAsset), call does not revert, but usdExposureProtocol is set to 0.
        }
        if (usdExposureProtocol >= riskParams[creditor].maxUsdExposureProtocol) {
            revert AssetModule.Exposure_Not_In_Limits();
        }
        riskParams[creditor].lastUsdExposureProtocol = uint128(usdExposureProtocol);
    }

    /**
     * @notice Update the exposure to an asset and it's underlying asset(s) on withdrawal.
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
     * @return usdExposureAsset The Usd value of the exposure of the asset, 18 decimals precision.
     */
    function _processWithdrawal(address creditor, bytes32 assetKey, uint256 exposureAsset)
        internal
        virtual
        returns (uint256 usdExposureAsset)
    {
        // Get the unique identifier(s) of the underlying asset(s).
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        // Get the exposure to the asset's underlying asset(s) (in the decimal precision of the underlying assets).
        (uint256[] memory exposureAssetToUnderlyingAssets,) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);

        int256 deltaExposureAssetToUnderlyingAsset;
        uint256 length = underlyingAssetKeys.length;
        for (uint256 i; i < length;) {
            // Calculate the change in exposure to the underlying assets since last interaction.
            deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAssets[i])
                - int256(uint256(lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]]));

            // Update "lastExposureAssetToUnderlyingAsset".
            lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]] =
                uint128(exposureAssetToUnderlyingAssets[i]); // ToDo: safecast?

            // Get the USD Value of the total exposure of "Asset" for for all of its "Underlying Assets".
            // If an "underlyingAsset" has one or more underlying assets itself, the lower level
            // Asset Modules will recursively update their respective exposures and return
            // the requested USD value to this Asset Module.
            (address underlyingAsset, uint256 underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdExposureAsset += IRegistry(REGISTRY).getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
                creditor,
                underlyingAsset,
                underlyingId,
                exposureAssetToUnderlyingAssets[i],
                deltaExposureAssetToUnderlyingAsset
            );

            unchecked {
                ++i;
            }
        }

        // Cache and update lastUsdExposureAsset.
        uint256 lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
        lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = uint128(usdExposureAsset);

        // Cache lastUsdExposureProtocol.
        uint256 lastUsdExposureProtocol = riskParams[creditor].lastUsdExposureProtocol;

        // Update lastUsdExposureProtocol.
        uint256 usdExposureProtocol;
        unchecked {
            if (usdExposureAsset >= lastUsdExposureAsset) {
                usdExposureProtocol = lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset);
                if (usdExposureProtocol > type(uint128).max) revert Overflow();
            } else if (lastUsdExposureProtocol > lastUsdExposureAsset - usdExposureAsset) {
                usdExposureProtocol = lastUsdExposureProtocol - (lastUsdExposureAsset - usdExposureAsset);
            }
        }
        // If (lastUsdExposureProtocol < lastUsdExposureAsset - usdExposureAsset), call does not revert, but usdExposureProtocol is set to 0.
        riskParams[creditor].lastUsdExposureProtocol = uint128(usdExposureProtocol);
    }

    /**
     * @notice Updates the exposure to the asset.
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param deltaAsset The increase or decrease in asset.
     * @return exposureAsset The updated exposure to the asset.
     */
    function _getAndUpdateExposureAsset(address creditor, bytes32 assetKey, int256 deltaAsset)
        internal
        returns (uint256 exposureAsset)
    {
        // Cache exposureAssetLast.
        uint256 exposureAssetLast = lastExposuresAsset[creditor][assetKey].lastExposureAsset;

        // Update exposureAssetLast.
        if (deltaAsset > 0) {
            exposureAsset = exposureAssetLast + uint256(deltaAsset);
        } else {
            exposureAsset = exposureAssetLast > uint256(-deltaAsset) ? exposureAssetLast - uint256(-deltaAsset) : 0;
        }
        lastExposuresAsset[creditor][assetKey].lastExposureAsset = uint128(exposureAsset); // ToDo: safecast?
    }
}
