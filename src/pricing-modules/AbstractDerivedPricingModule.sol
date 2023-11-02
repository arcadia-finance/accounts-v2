/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IMainRegistry, PricingModule } from "./AbstractPricingModule.sol";
import { RiskConstants } from "../libraries/RiskConstants.sol";

/**
 * @title Derived Pricing Module.
 * @author Pragma Labs
 */
abstract contract DerivedPricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier indicating that it is a Derived Pricing Module and not a Primary Pricing Module.
    // The assets being priced do have underlying assets.
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
        // The risk factor of the protocol for a creditor, 2 decimals precision.
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
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    constructor(address mainRegistry_, uint256 assetType_) PricingModule(mainRegistry_, assetType_) { }

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
                GetValueInput({
                    asset: underlyingAsset,
                    assetId: underlyingAssetId,
                    assetAmount: 1e18,
                    creditor: address(0)
                })
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
                    RISK VARIABLES MANAGEMENT
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
        virtual
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    { }

    /**
     * @notice Sets the risk parameters of the Protocol for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param maxUsdExposureProtocol_ The maximum usd exposure of the protocol for each creditor, denominated in USD with 18 decimals precision.
     * @param riskFactor The risk factor of the asset for the creditor, 2 decimals precision.
     */
    function setRiskParameters(address creditor, uint128 maxUsdExposureProtocol_, uint16 riskFactor)
        external
        onlyMainReg
    {
        require(riskFactor <= RiskConstants.RISK_FACTOR_UNIT, "ADPM_SRP: Risk Fact not in limits");

        riskParams[creditor].maxUsdExposureProtocol = maxUsdExposureProtocol_;
        riskParams[creditor].riskFactor = riskFactor;
    }

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
                getValueInput.asset = underlyingAsset;
                getValueInput.assetId = underlyingAssetId;
                getValueInput.assetAmount = underlyingAssetsAmounts[i];

                valueInUsd += IMainRegistry(MAIN_REGISTRY).getUsdValue(getValueInput);

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

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, int256(amount));

        _processDeposit(creditor, assetKey, exposureAsset);
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
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
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

        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, -int256(amount));

        _processWithdrawal(creditor, assetKey, exposureAsset);
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
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
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
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
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
            _getUnderlyingAssetsAmounts(assetKey, exposureAsset, underlyingAssetKeys);

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
            // Pricing Modules will recursively update their respective exposures and return
            // the requested USD value to this Pricing Module.
            (address underlyingAsset, uint256 underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdExposureAsset += IMainRegistry(MAIN_REGISTRY).getUsdValueExposureToUnderlyingAssetAfterDeposit(
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
        // ToDo: also in else case a deposit should be blocked if final exposure is bigger than maxExposure?.
        if (usdExposureAsset >= lastUsdExposureAsset) {
            require(
                lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset)
                    <= riskParams[creditor].maxUsdExposureProtocol,
                "ADPM_PD: Exposure not in limits"
            );
            riskParams[creditor].lastUsdExposureProtocol =
                uint128(lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset));
        } else {
            riskParams[creditor].lastUsdExposureProtocol = uint128(
                lastUsdExposureProtocol > lastUsdExposureAsset - usdExposureAsset
                    ? lastUsdExposureProtocol - (lastUsdExposureAsset - usdExposureAsset)
                    : 0
            );
        }
    }

    /**
     * @notice Update the exposure to an asset and it's underlying asset(s) on withdrawal.
     * @param assetKey The unique identifier of the asset.
     * @param exposureAsset The updated exposure to the asset.
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
            _getUnderlyingAssetsAmounts(assetKey, exposureAsset, underlyingAssetKeys);

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
            // Pricing Modules will recursively update their respective exposures and return
            // the requested USD value to this Pricing Module.
            (address underlyingAsset, uint256 underlyingId) = _getAssetFromKey(underlyingAssetKeys[i]);
            usdExposureAsset += IMainRegistry(MAIN_REGISTRY).getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
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
        if (usdExposureAsset >= lastUsdExposureAsset) {
            require(
                lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset) <= type(uint128).max,
                "ADPM_PW: Overflow"
            );
            riskParams[creditor].lastUsdExposureProtocol =
                uint128(lastUsdExposureProtocol + (usdExposureAsset - lastUsdExposureAsset));
        } else {
            riskParams[creditor].lastUsdExposureProtocol = uint128(
                lastUsdExposureProtocol > lastUsdExposureAsset - usdExposureAsset
                    ? lastUsdExposureProtocol - (lastUsdExposureAsset - usdExposureAsset)
                    : 0
            );
        }
    }

    /**
     * @notice Updates the exposure to the asset.
     * @param assetKey The unique identifier of the asset.
     * @param deltaAsset The increase or decrease in asset.
     * @return exposureAsset The updated exposure to the asset
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
