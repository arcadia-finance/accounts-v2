/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetModule } from "./AbstractAM.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "../../../lib/solmate/src/utils/SafeCastLib.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";

/**
 * @title Derived Asset Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a Derived Asset Module.
 * @dev Derived Assets are assets with underlying assets, the underlying assets can be Primary Assets or also Derived Assets.
 * For Derived Assets there are no direct external oracles.
 * USD values of assets must be calculated in a recursive manner via the pricing logic of the Underlying Assets.
 */
abstract contract DerivedAM is AssetModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map with the risk parameters of the protocol for each Creditor.
    mapping(address creditor => RiskParameters riskParameters) public riskParams;
    // Map with the last exposures of each asset for each Creditor.
    mapping(address creditor => mapping(bytes32 assetKey => ExposuresPerAsset)) internal lastExposuresAsset;
    // Map with the last amount of exposure of each underlying asset for each asset for each Creditor.
    mapping(address creditor => mapping(bytes32 assetKey => mapping(bytes32 underlyingAssetKey => uint256 exposure)))
        internal lastExposureAssetToUnderlyingAsset;

    // Struct with the risk parameters of the protocol for a specific Creditor.
    struct RiskParameters {
        // The exposure in USD of the Creditor to the protocol at the last interaction, 18 decimals precision.
        uint112 lastUsdExposureProtocol;
        // The maximum exposure in USD of the Creditor to the protocol, 18 decimals precision.
        uint112 maxUsdExposureProtocol;
        // The risk factor of the protocol for a Creditor, 4 decimals precision.
        uint16 riskFactor;
    }

    // Struct with the exposures of a specific asset for a specific Creditor.
    struct ExposuresPerAsset {
        // The amount of exposure of the Creditor to the asset at the last interaction.
        uint112 lastExposureAsset;
        // The exposure in USD of the Creditor to the asset at the last interaction, 18 decimals precision.
        uint112 lastUsdExposureAsset;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error RiskFactorNotInLimits();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * ...
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
     * @notice Calculates the USD rate of 10**18 underlying assets.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @dev The USD price per 10**18 tokens is used (instead of the USD price per token) to guarantee sufficient precision.
     */
    function _getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        internal
        view
        virtual
        returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        uint256 length = underlyingAssetKeys.length;

        address[] memory underlyingAssets = new address[](length);
        uint256[] memory underlyingAssetIds = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            (underlyingAssets[i], underlyingAssetIds[i]) = _getAssetFromKey(underlyingAssetKeys[i]);
            // We use the USD price per 10**18 tokens instead of the USD price per token to guarantee
            // sufficient precision.
            amounts[i] = 1e18;
        }

        rateUnderlyingAssetsToUsd =
            IRegistry(REGISTRY).getValuesInUsdRecursive(creditor, underlyingAssets, underlyingAssetIds, amounts);
    }

    /**
     * @notice Calculates for a given amount of an Asset the corresponding amount(s) of Underlying Asset(s).
     * @param creditor The contract address of the Creditor.
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @dev The USD price per 10**18 tokens is used (instead of the USD price per token) to guarantee sufficient precision.
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
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd);

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
        virtual
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor);

    /**
     * @notice Sets the risk parameters of the Protocol for a given Creditor.
     * @param creditor The contract address of the Creditor.
     * @param maxUsdExposureProtocol_ The maximum USD exposure of the protocol for each Creditor, denominated in USD with 18 decimals precision.
     * @param riskFactor The risk factor of the asset for the Creditor, 4 decimals precision.
     */
    function setRiskParameters(address creditor, uint112 maxUsdExposureProtocol_, uint16 riskFactor)
        external
        onlyRegistry
    {
        if (riskFactor > AssetValuationLib.ONE_4) revert RiskFactorNotInLimits();

        riskParams[creditor].maxUsdExposureProtocol = maxUsdExposureProtocol_;
        riskParams[creditor].riskFactor = riskFactor;
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
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
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

        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, assetAmount, underlyingAssetKeys);

        // Check if rateToUsd for the underlying assets was already calculated in _getUnderlyingAssetsAmounts().
        if (rateUnderlyingAssetsToUsd.length == 0) {
            // If not, get the USD value of the underlying assets recursively.
            rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
        }

        (valueInUsd, collateralFactor, liquidationFactor) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev We take the most conservative (lowest) risk factor of all underlying assets.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    ) internal view virtual returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor);

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
        returns (uint256 recursiveCalls, uint256 assetType)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to Asset.
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, int256(amount));

        (uint256 underlyingCalls,) = _processDeposit(exposureAsset, creditor, assetKey);

        unchecked {
            recursiveCalls = underlyingCalls + 1;
        }
        assetType = ASSET_TYPE;
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
     * @dev An indirect deposit, is initiated by a deposit of another derived asset (the upper asset),
     * from which the asset of this Asset Module is an underlying asset.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, deltaExposureUpperAssetToAsset);

        (uint256 underlyingCalls, uint256 usdExposureAsset) = _processDeposit(exposureAsset, creditor, assetKey);

        if (exposureAsset == 0 || usdExposureAsset == 0) {
            usdExposureUpperAssetToAsset = 0;
        } else {
            // Calculate the USD value of the exposure of the upper asset to the underlying asset.
            usdExposureUpperAssetToAsset = usdExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);
        }

        unchecked {
            recursiveCalls = underlyingCalls + 1;
        }
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
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyRegistry
        returns (uint256 assetType)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, -int256(amount));

        _processWithdrawal(creditor, assetKey, exposureAsset);

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
     * @dev An indirect withdrawal is initiated by a withdrawal of another Derived Asset (the upper asset),
     * from which the asset of this Asset Module is an Underlying Asset.
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyRegistry returns (uint256 usdExposureUpperAssetToAsset) {
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
    }

    /**
     * @notice Update the exposure to an asset and its underlying asset(s) on deposit.
     * @param exposureAsset The updated exposure to the asset.
     * @param creditor The contract address of the Creditor.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingCalls The number of calls done to different asset modules to process the deposit/withdrawal of the underlying assets.
     * @return usdExposureAsset The USD value of the exposure of the asset, 18 decimals precision.
     * @dev The checks on exposures are only done to block deposits that would over-expose a Creditor to a certain asset or protocol.
     * Underflows will not revert, but the exposure is instead set to 0.
     */
    function _processDeposit(uint256 exposureAsset, address creditor, bytes32 assetKey)
        internal
        virtual
        returns (uint256 underlyingCalls, uint256 usdExposureAsset)
    {
        uint256 usdExposureProtocol;
        {
            // Get the unique identifier(s) of the underlying asset(s).
            bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

            // Get the exposure to the asset's underlying asset(s) (in the decimal precision of the underlying assets).
            (uint256[] memory exposureAssetToUnderlyingAssets,) =
                _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);

            int256 deltaExposureAssetToUnderlyingAsset;
            address underlyingAsset;
            uint256 underlyingId;
            uint256 underlyingCalls_;
            uint256 usdExposureToUnderlyingAsset;

            for (uint256 i; i < underlyingAssetKeys.length; ++i) {
                // Calculate the change in exposure to the underlying assets since last interaction.
                deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAssets[i])
                    - int256(uint256(lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]]));

                // Update "lastExposureAssetToUnderlyingAsset".
                lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]] =
                    exposureAssetToUnderlyingAssets[i];

                // Get the USD Value of the total exposure of "Asset" for its "Underlying Assets" at index "i".
                // If the "underlyingAsset" has one or more underlying assets itself, the lower level
                // Asset Module(s) will recursively update their respective exposures and return
                // the requested USD value to this Asset Module.
                (underlyingAsset, underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
                (underlyingCalls_, usdExposureToUnderlyingAsset) = IRegistry(REGISTRY)
                    .getUsdValueExposureToUnderlyingAssetAfterDeposit(
                    creditor,
                    underlyingAsset,
                    underlyingId,
                    exposureAssetToUnderlyingAssets[i],
                    deltaExposureAssetToUnderlyingAsset
                );
                usdExposureAsset += usdExposureToUnderlyingAsset;
                unchecked {
                    underlyingCalls += underlyingCalls_;
                }
            }

            // Cache and update lastUsdExposureAsset.
            uint256 lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
            // If usdExposureAsset is bigger than uint112, then check on usdExposureProtocol below will revert.
            lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = uint112(usdExposureAsset);

            // Cache lastUsdExposureProtocol.
            uint256 lastUsdExposureProtocol = riskParams[creditor].lastUsdExposureProtocol;

            // Update lastUsdExposureProtocol.
            unchecked {
                if (usdExposureAsset >= lastUsdExposureAsset) {
                    usdExposureProtocol = lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset);
                } else if (lastUsdExposureProtocol > lastUsdExposureAsset - usdExposureAsset) {
                    usdExposureProtocol = lastUsdExposureProtocol - (lastUsdExposureAsset - usdExposureAsset);
                }
                // For the else case: (lastUsdExposureProtocol < lastUsdExposureAsset - usdExposureAsset),
                // usdExposureProtocol is set to 0, but usdExposureProtocol is already 0.
            }
            // The exposure must be strictly smaller than the maxExposure, not equal to or smaller than.
            // This is to ensure that all deposits revert when maxExposure is set to 0, also deposits with 0 amounts.
            if (usdExposureProtocol >= riskParams[creditor].maxUsdExposureProtocol) {
                revert AssetModule.ExposureNotInLimits();
            }
        }
        riskParams[creditor].lastUsdExposureProtocol = uint112(usdExposureProtocol);
    }

    /**
     * @notice Update the exposure to an asset and its underlying asset(s) on withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
     * @return usdExposureAsset The USD value of the exposure of the asset, 18 decimals precision.
     * @dev The checks on exposures are only done to block deposits that would over-expose a Creditor to a certain asset or protocol.
     * Underflows will not revert, but the exposure is instead set to 0.
     * @dev Due to changing usd-prices of underlying assets, or due to changing compositions of upper assets,
     * the exposure to a derived asset can increase or decrease over time independent of deposits/withdrawals.
     * When derived assets are deposited/withdrawn, these changes in exposure since last interaction are also synced.
     * As such the actual exposure on a withdrawal of a derived asset can exceed the maxExposure, but this should never be blocked,
     * (the withdrawal actually improves the situation by making the asset less over-exposed).
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
        address underlyingAsset;
        uint256 underlyingId;

        for (uint256 i; i < underlyingAssetKeys.length; ++i) {
            // Calculate the change in exposure to the underlying assets since last interaction.
            deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAssets[i])
                - int256(uint256(lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]]));

            // Update "lastExposureAssetToUnderlyingAsset".
            lastExposureAssetToUnderlyingAsset[creditor][assetKey][underlyingAssetKeys[i]] =
                exposureAssetToUnderlyingAssets[i];

            // Get the USD Value of the total exposure of "Asset" for for all of its "Underlying Assets".
            // If an "underlyingAsset" has one or more underlying assets itself, the lower level
            // Asset Modules will recursively update their respective exposures and return
            // the requested USD value to this Asset Module.
            (underlyingAsset, underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdExposureAsset += IRegistry(REGISTRY).getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
                creditor,
                underlyingAsset,
                underlyingId,
                exposureAssetToUnderlyingAssets[i],
                deltaExposureAssetToUnderlyingAsset
            );
        }

        // Cache and update lastUsdExposureAsset.
        uint256 lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
        // If usdExposureAsset is bigger than uint112, then safecast on usdExposureProtocol below will revert.
        lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = uint112(usdExposureAsset);

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
            // For the else case: (lastUsdExposureProtocol < lastUsdExposureAsset - usdExposureAsset),
            // usdExposureProtocol is set to 0, but usdExposureProtocol is already 0.
        }
        riskParams[creditor].lastUsdExposureProtocol = SafeCastLib.safeCastTo112(usdExposureProtocol);
    }

    /**
     * @notice Updates the exposure to the asset.
     * @param creditor The contract address of the Creditor.
     * @param assetKey The unique identifier of the asset.
     * @param deltaAsset The increase or decrease in asset amount since the last interaction.
     * @return exposureAsset The updated exposure to the asset.
     * @dev The checks on exposures are only done to block deposits that would over-expose a Creditor to a certain asset or protocol.
     * Underflows will not revert, but the exposure is instead set to 0.
     */
    function _getAndUpdateExposureAsset(address creditor, bytes32 assetKey, int256 deltaAsset)
        internal
        returns (uint256 exposureAsset)
    {
        // Update exposureAssetLast.
        if (deltaAsset > 0) {
            exposureAsset = lastExposuresAsset[creditor][assetKey].lastExposureAsset + uint256(deltaAsset);
        } else {
            uint256 exposureAssetLast = lastExposuresAsset[creditor][assetKey].lastExposureAsset;
            exposureAsset = exposureAssetLast > uint256(-deltaAsset) ? exposureAssetLast - uint256(-deltaAsset) : 0;
        }
        lastExposuresAsset[creditor][assetKey].lastExposureAsset = SafeCastLib.safeCastTo112(exposureAsset);
    }
}
