/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IMainRegistry, PricingModule } from "./AbstractPricingModule.sol";

/**
 * @title Derived Pricing Module.
 * @author Pragma Labs
 */
abstract contract DerivedPricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier indicating that it is not a Primary Pricing Module:
    // the assets being priced do have underlying assets.
    bool internal constant PRIMARY_FLAG = false;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The maximum total exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
    uint256 public maxUsdExposureProtocol;
    // The actual exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
    uint256 public usdExposureProtocol;

    // Map with the last exposures of each asset.
    mapping(bytes32 assetKey => ExposurePerAsset exposure) internal assetToExposureLast;
    // Map with the last exposures of each asset to its underlying assets..
    mapping(bytes32 assetKey => mapping(bytes32 underlyingAssetKey => uint256 exposure)) internal
        exposureAssetToUnderlyingAssetsLast;

    // Struct with information about the exposure of a specific asset.
    struct ExposurePerAsset {
        uint128 exposureLast;
        uint128 usdValueExposureLast;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event MaxUsdExposureProtocolSet(uint256 maxExposure);
    event UsdExposureChanged(uint256 oldExposure, uint256 newExposure);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @param riskManager_ The address of the Risk Manager.
     */
    constructor(address mainRegistry_, uint256 assetType_, address riskManager_)
        PricingModule(mainRegistry_, assetType_, riskManager_)
    { }

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
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getRateUnderlyingAssetsToUsd(bytes32[] memory underlyingAssetKeys)
        internal
        view
        virtual
        returns (uint256[] memory rateUnderlyingAssetsToUsd)
    {
        uint256 length = underlyingAssetKeys.length;
        rateUnderlyingAssetsToUsd = new uint256[](length);

        address underlyingAsset;
        uint256 underlyingAssetId;
        for (uint256 i; i < length;) {
            (underlyingAsset, underlyingAssetId) = _getAssetFromKey(underlyingAssetKeys[i]);

            // We use the USD price per 10^18 tokens instead of the USD price per token to guarantee
            // sufficient precision.
            rateUnderlyingAssetsToUsd[i] = IMainRegistry(MAIN_REGISTRY).getUsdValue(
                GetValueInput({ asset: underlyingAsset, assetId: underlyingAssetId, assetAmount: 1e18, baseCurrency: 0 })
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(bytes32 assetKey, uint256 assetAmount, bytes32[] memory underlyingAssetKeys)
        internal
        view
        virtual
        returns (uint256[] memory underlyingAssetsAmounts, uint256[] memory rateUnderlyingAssetsToUsd);

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * @param getValueInput A Struct with the input variables.
     * - asset: The contract address of the asset.
     * - assetId: The Id of the asset.
     * - assetAmount: The amount of assets.
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        virtual
        override
        returns (uint256 valueInUsd, uint256, uint256)
    {
        bytes32 assetKey = _getKeyFromAsset(getValueInput.asset, getValueInput.assetId);

        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        (uint256[] memory underlyingAssetsAmounts, uint256[] memory rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(assetKey, getValueInput.assetAmount, underlyingAssetKeys);

        uint256 length = underlyingAssetKeys.length;
        // Check if rateToUsd for the underlying assets was already calculated in _getUnderlyingAssetsAmounts().
        if (rateUnderlyingAssetsToUsd.length == 0) {
            // If not, get the usd value of the underlying assets recursively.
            address underlyingAsset;
            uint256 underlyingAssetId;
            for (uint256 i; i < length;) {
                (underlyingAsset, underlyingAssetId) = _getAssetFromKey(underlyingAssetKeys[i]);

                valueInUsd += IMainRegistry(MAIN_REGISTRY).getUsdValue(
                    GetValueInput({
                        asset: underlyingAsset,
                        assetId: underlyingAssetId,
                        assetAmount: underlyingAssetsAmounts[i],
                        baseCurrency: 0
                    })
                );

                unchecked {
                    ++i;
                }
            }
        } else {
            // If yes, directly calculate the usdValue from the underlying amounts and values.
            for (uint256 i; i < length;) {
                // "rateUnderlyingAssetsToUsd" is the usd value with 18 decimals precision for 10 ** 18 tokens of Underlying Asset.
                // To get the usd value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
                // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
                valueInUsd +=
                    FixedPointMathLib.mulDivDown(underlyingAssetsAmounts[i], rateUnderlyingAssetsToUsd[i], 1e18);

                unchecked {
                    ++i;
                }
            }
        }

        return (valueInUsd, 0, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum exposure for the protocol.
     * @param maxUsdExposureProtocol_ The maximum total exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
     * @dev Can only be called by the Risk Manager, which can be different from the owner.
     */
    function setMaxUsdExposureProtocol(uint256 maxUsdExposureProtocol_) public virtual onlyRiskManager {
        maxUsdExposureProtocol = maxUsdExposureProtocol_;

        emit MaxUsdExposureProtocolSet(maxUsdExposureProtocol_);
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
    function processDirectDeposit(address asset, uint256 assetId, uint256 amount) public virtual override onlyMainReg {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(assetKey, int256(amount));

        _processDeposit(assetKey, exposureAsset);
    }

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectDeposit(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(assetKey, deltaExposureUpperAssetToAsset);

        uint256 usdValueExposureAsset = _processDeposit(assetKey, exposureAsset);

        if (exposureAsset == 0 || usdValueExposureAsset == 0) {
            usdValueExposureUpperAssetToAsset = 0;
        } else {
            // Calculate the USD value of the exposure of the upper asset to the underlying asset.
            usdValueExposureUpperAssetToAsset =
                usdValueExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);
        }

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @dev Unsafe cast to uint128, it is assumed no more than 10**(20+decimals) tokens will ever be deposited.
     */
    function processDirectWithdrawal(address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyMainReg
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(assetKey, -int256(amount));

        _processWithdrawal(assetKey, exposureAsset);
    }

    /**
     * @notice Decreases the exposure to an underlying asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectWithdrawal(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(assetKey, deltaExposureUpperAssetToAsset);

        uint256 usdValueExposureAsset = _processWithdrawal(assetKey, exposureAsset);

        if (exposureAsset == 0 || usdValueExposureAsset == 0) {
            usdValueExposureUpperAssetToAsset = 0;
        } else {
            // Calculate the USD value of the exposure of the Upper Asset to the Underlying asset.
            usdValueExposureUpperAssetToAsset =
                usdValueExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);
        }

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Update the exposure to an asset and it's underlying asset(s) on deposit.
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
     */
    function _processDeposit(bytes32 assetKey, uint256 exposureAsset)
        internal
        virtual
        returns (uint256 usdValueExposureAsset)
    {
        // Get the unique identifiers of the underlying asset(s).
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        // Get the exposure to the asset's underlying asset(s) (in the decimal precision of the underlying assets).
        (uint256[] memory exposureAssetToUnderlyingAssets,) =
            _getUnderlyingAssetsAmounts(assetKey, exposureAsset, underlyingAssetKeys);

        int256 deltaExposureAssetToUnderlyingAsset;
        uint256 length = underlyingAssetKeys.length;
        for (uint256 i; i < length;) {
            // Calculate the change in exposure to the underlying assets since last interaction.
            deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAssets[i])
                - int256(uint256(exposureAssetToUnderlyingAssetsLast[assetKey][underlyingAssetKeys[i]]));

            // Update "exposureAssetToUnderlyingAssetLast".
            exposureAssetToUnderlyingAssetsLast[assetKey][underlyingAssetKeys[i]] =
                uint128(exposureAssetToUnderlyingAssets[i]); // ToDo: safecast?

            // Get the USD Value of the total exposure of "Asset" for for all of its "Underlying Assets".
            // If an "underlyingAsset" has one or more underlying assets itself, the lower level
            // Pricing Modules will recursively update their respective exposures and return
            // the requested USD value to this Pricing Module.
            (address underlyingAsset, uint256 underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdValueExposureAsset += IMainRegistry(MAIN_REGISTRY).getUsdValueExposureToUnderlyingAssetAfterDeposit(
                underlyingAsset, underlyingId, exposureAssetToUnderlyingAssets[i], deltaExposureAssetToUnderlyingAsset
            );

            unchecked {
                ++i;
            }
        }

        // Cache usdValueExposureAssetLast and update usdValueExposureAssetLast.
        uint256 usdValueExposureAssetLast = assetToExposureLast[assetKey].usdValueExposureLast;
        assetToExposureLast[assetKey].usdValueExposureLast = uint128(usdValueExposureAsset);

        // Cache usdExposureProtocol.
        uint256 usdExposureProtocolLast = usdExposureProtocol;

        // Update usdExposureProtocolLast.
        // ToDo: also in else case a deposit should be blocked if final exposure is bigger as maxExposure?.
        if (usdValueExposureAsset >= usdValueExposureAssetLast) {
            require(
                usdExposureProtocolLast + (usdValueExposureAsset - usdValueExposureAssetLast) <= maxUsdExposureProtocol,
                "ADPM_PD: Exposure not in limits"
            );
            usdExposureProtocol = usdExposureProtocolLast + (usdValueExposureAsset - usdValueExposureAssetLast);
        } else {
            usdExposureProtocol = usdExposureProtocolLast > usdValueExposureAssetLast - usdValueExposureAsset
                ? usdExposureProtocolLast - (usdValueExposureAssetLast - usdValueExposureAsset)
                : 0;
        }

        emit UsdExposureChanged(usdExposureProtocolLast, usdExposureProtocol);
    }

    /**
     * @notice Update the exposure to an asset and it's underlying asset(s) on withdrawal.
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
     */
    function _processWithdrawal(bytes32 assetKey, uint256 exposureAsset)
        internal
        virtual
        returns (uint256 usdValueExposureAsset)
    {
        // Get the unique identifiers of the underlying asset(s).
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        // Get the exposure to the asset's underlying asset(s) (in the decimal precision of the underlying assets).
        (uint256[] memory exposureAssetToUnderlyingAssets,) =
            _getUnderlyingAssetsAmounts(assetKey, exposureAsset, underlyingAssetKeys);

        int256 deltaExposureAssetToUnderlyingAsset;
        uint256 length = underlyingAssetKeys.length;
        for (uint256 i; i < length;) {
            // Calculate the change in exposure to the underlying assets since last interaction.
            deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAssets[i])
                - int256(uint256(exposureAssetToUnderlyingAssetsLast[assetKey][underlyingAssetKeys[i]]));

            // Update "exposureAssetToUnderlyingAssetLast".
            exposureAssetToUnderlyingAssetsLast[assetKey][underlyingAssetKeys[i]] =
                uint128(exposureAssetToUnderlyingAssets[i]); // ToDo: safecast?

            // Get the USD Value of the total exposure of "Asset" for for all of its "Underlying Assets".
            // If an "underlyingAsset" has one or more underlying assets itself, the lower level
            // Pricing Modules will recursively update their respective exposures and return
            // the requested USD value to this Pricing Module.
            (address underlyingAsset, uint256 underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdValueExposureAsset += IMainRegistry(MAIN_REGISTRY).getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
                underlyingAsset, underlyingId, exposureAssetToUnderlyingAssets[i], deltaExposureAssetToUnderlyingAsset
            );

            unchecked {
                ++i;
            }
        }

        // Cache usdValueExposureAssetLast and update usdValueExposureAssetLast.
        uint256 usdValueExposureAssetLast = assetToExposureLast[assetKey].usdValueExposureLast;
        assetToExposureLast[assetKey].usdValueExposureLast = uint128(usdValueExposureAsset);

        // Cache usdExposureProtocol.
        uint256 usdExposureProtocolLast = usdExposureProtocol;

        // Update usdExposureProtocolLast.
        if (usdValueExposureAsset >= usdValueExposureAssetLast) {
            usdExposureProtocol = usdExposureProtocolLast + (usdValueExposureAsset - usdValueExposureAssetLast);
        } else {
            usdExposureProtocol = usdExposureProtocolLast > usdValueExposureAssetLast - usdValueExposureAsset
                ? usdExposureProtocolLast - (usdValueExposureAssetLast - usdValueExposureAsset)
                : 0;
        }

        emit UsdExposureChanged(usdExposureProtocolLast, usdExposureProtocol);
    }

    /**
     * @notice Updates the exposure to the asset.
     * @param assetKey The unique identifier of the asset.
     * @param deltaAsset The increase or decrease in asset.
     * @return exposureAsset The updated exposure to the asset
     */
    function _getAndUpdateExposureAsset(bytes32 assetKey, int256 deltaAsset) internal returns (uint256 exposureAsset) {
        // Cache the old exposure to the asset.
        uint256 exposureAssetLast = assetToExposureLast[assetKey].exposureLast;
        // Calculate and store the new exposure.
        if (deltaAsset > 0) {
            exposureAsset = exposureAssetLast + uint256(deltaAsset);
        } else {
            exposureAsset = exposureAssetLast > uint256(-deltaAsset) ? exposureAssetLast - uint256(-deltaAsset) : 0;
        }
        assetToExposureLast[assetKey].exposureLast = uint128(exposureAsset); // ToDo: safecast?
    }
}
