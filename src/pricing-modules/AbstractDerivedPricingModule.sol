/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { PricingModule } from "./AbstractPricingModule_New.sol";
import { IPricingModule } from "../interfaces/IPricingModule_New.sol";
import { Owned } from "../../lib/solmate/src/auth/Owned.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry_New.sol";

/**
 * @title Derived Pricing Module.
 * @author Pragma Labs
 */
abstract contract DerivedPricingModule is PricingModule {
    using FixedPointMathLib for uint256;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    bool internal constant PRIMARY_FLAG = false;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // TODO: uint128 should be enough for USD Exposure ?
    // The maximum total exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
    uint256 maxUsdExposureProtocol;
    // The actual exposure of the protocol of this Pricing Module, denominated in USD with 18 decimals precision.
    uint256 usdExposureProtocol;

    // Map asset => assetExposure.
    mapping(address => uint256) public assetExposure;
    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint128 exposureAssetLast;
        uint128 usdValueExposureAssetLast;
        address[] underlyingAssets;
        uint128[] exposureAssetToUnderlyingAssetsLast;
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
     * @param oracleHub_ The contract address of the OracleHub.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @param riskManager_ The address of the Risk Manager.
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        PricingModule(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the information that is stored in the Sub-registry for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     */
    function getAssetInformation(address asset)
        external
        view
        returns (uint128, uint128, address[] memory, uint128[] memory)
    {
        return (
            assetToInformation[asset].exposureAssetLast,
            assetToInformation[asset].usdValueExposureAssetLast,
            assetToInformation[asset].underlyingAssets,
            assetToInformation[asset].exposureAssetToUnderlyingAssetsLast
        );
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function _getConversionRate(address asset, address underlyingAsset)
        internal
        view
        virtual
        returns (uint256 conversionRate)
    { }

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

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address asset, uint256, uint256 amount) external virtual override onlyMainReg {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, int256(amount));

        _processDeposit(asset, 0, exposureAsset);
    }

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param exposureUpperAssetToAsset .
     * @param deltaExposureUpperAssetToAsset .
     */
    function processIndirectDeposit(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) external virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, deltaExposureUpperAssetToAsset);

        uint256 usdValueExposureAsset = _processDeposit(asset, 0, exposureAsset);

        // Calculate the USD value of the exposure of the Upper Asset to the Underlying asset.
        usdValueExposureUpperAssetToAsset = usdValueExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @dev Unsafe cast to uint128, it is assumed no more than 10**(20+decimals) tokens will ever be deposited.
     */
    function processDirectWithdrawal(address asset, uint256, uint256 amount) external virtual override onlyMainReg {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, -int256(amount));

        _processWithdrawal(asset, 0, exposureAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param exposureUpperAssetToAsset .
     * @param deltaExposureUpperAssetToAsset .
     */
    function processIndirectWithdrawal(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) external virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, deltaExposureUpperAssetToAsset);

        uint256 usdValueExposureAsset = _processWithdrawal(asset, 0, exposureAsset);

        // Calculate the USD value of the exposure of the Upper Asset to the Underlying asset.
        usdValueExposureUpperAssetToAsset = usdValueExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param exposureAsset The updated exposure to the asset.
     */
    function _processDeposit(address asset, uint256, uint256 exposureAsset)
        internal
        virtual
        onlyMainReg
        returns (uint256 usdValueExposureAsset)
    {
        // Cache values
        address[] memory underlyingAssets = assetToInformation[asset].underlyingAssets;

        uint256 usdValueExposureAssetToUnderlyingAssets;
        for (uint8 i; i < assetToInformation[asset].underlyingAssets.length;) {
            // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
            uint256 conversionRate = _getConversionRate(asset, underlyingAssets[i]);

            // Calculate and update the total exposure, and the delta since last interaction, of "Asset" to "Underlying Asset".
            (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) =
                _getUnderlyingAssetExposures(asset, exposureAsset, conversionRate, i);

            // Get the USD Value of the total exposure of "Asset" for "Underlying Asset.
            // If "underlyingAsset" has one or more underlying assets itself, the lower level
            // Pricing Modules will recursively update their respective exposures and return
            // the requested USD value to this Pricing Module.
            usdValueExposureAssetToUnderlyingAssets += IMainRegistry(mainRegistry)
                .getUsdExposureUnderlyingAssetAfterDeposit(
                underlyingAssets[i], 0, exposureAssetToUnderlyingAsset, deltaExposureAssetToUnderlyingAsset
            );

            unchecked {
                ++i;
            }
        }

        usdValueExposureAsset = usdValueExposureAssetToUnderlyingAssets;

        // Cache usdValueExposureAssetLast and update usdValueExposureAssetLast.
        uint256 usdValueExposureAssetLast = assetToInformation[asset].usdValueExposureAssetLast;
        assetToInformation[asset].usdValueExposureAssetLast = uint128(usdValueExposureAsset);

        // Cache usdExposureProtocol.
        uint256 usdExposureProtocolLast = usdExposureProtocol;

        // Update usdExposureProtocolLast.
        if (usdValueExposureAsset >= usdValueExposureAssetLast) {
            require(
                usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast <= maxUsdExposureProtocol,
                "ADPM_PDD: Exposure not in limits"
            );
            usdExposureProtocol = usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast;
        } else {
            usdExposureProtocol = usdExposureProtocolLast > usdValueExposureAssetLast - usdValueExposureAsset
                ? usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast
                : 0;
        }

        emit UsdExposureChanged(usdExposureProtocolLast, usdExposureProtocol);
    }

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param exposureAsset The updated exposure to the asset.
     */
    function _processWithdrawal(address asset, uint256, uint256 exposureAsset)
        internal
        virtual
        onlyMainReg
        returns (uint256 usdValueExposureAsset)
    {
        // Cache values
        address[] memory underlyingAssets = assetToInformation[asset].underlyingAssets;

        uint256 usdValueExposureAssetToUnderlyingAssets;
        for (uint8 i; i < assetToInformation[asset].underlyingAssets.length;) {
            // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
            uint256 conversionRate = _getConversionRate(asset, underlyingAssets[i]);

            // Calculate and update the total exposure, and the delta since last interaction, of "Asset" to "Underlying Asset".
            (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) =
                _getUnderlyingAssetExposures(asset, exposureAsset, conversionRate, i);

            // Get the USD Value of the total exposure of "Asset" for "Underlying Asset.
            // If "underlyingAsset" has one or more underlying assets itself, the lower level
            // Pricing Modules will recursively update their respective exposures and return
            // the requested USD value to this Pricing Module.
            usdValueExposureAssetToUnderlyingAssets += IMainRegistry(mainRegistry)
                .getUsdExposureUnderlyingAssetAfterWithdrawal(
                underlyingAssets[i], 0, exposureAssetToUnderlyingAsset, deltaExposureAssetToUnderlyingAsset
            );

            unchecked {
                ++i;
            }
        }

        usdValueExposureAsset = usdValueExposureAssetToUnderlyingAssets;

        // Cache usdValueExposureAssetLast and update usdValueExposureAssetLast.
        uint256 usdValueExposureAssetLast = assetToInformation[asset].usdValueExposureAssetLast;
        assetToInformation[asset].usdValueExposureAssetLast = uint128(usdValueExposureAsset);

        // Cache usdExposureProtocol.
        uint256 usdExposureProtocolLast = usdExposureProtocol;

        // Update usdExposureProtocolLast.
        if (usdValueExposureAsset >= usdValueExposureAssetLast) {
            usdExposureProtocol = usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast;
        } else {
            usdExposureProtocol = usdExposureProtocolLast > usdValueExposureAssetLast - usdValueExposureAsset
                ? usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast
                : 0;
        }

        emit UsdExposureChanged(usdExposureProtocolLast, usdExposureProtocol);
    }

    /**
     * @notice Updates the exposure to the asset.
     * @param asset The contract address of the asset.
     * @param deltaAsset The increase or decrease in asset.
     * @return exposureAsset The updated exposure to the asset
     */
    function _getExposureAsset(address asset, int256 deltaAsset) internal returns (uint256 exposureAsset) {
        // Cache the old exposure to the asset.
        uint256 exposureAssetLast = assetToInformation[asset].exposureAssetLast;
        // Calculate and store the new exposure.
        if (deltaAsset > 0) {
            exposureAsset = exposureAssetLast + uint256(deltaAsset);
        } else {
            exposureAsset = exposureAssetLast > uint256(-deltaAsset) ? exposureAssetLast - uint256(-deltaAsset) : 0;
        }
        assetToInformation[asset].exposureAssetLast = uint128(exposureAsset); // ToDo: safecast?
    }

    /**
     * @notice Calculates the exposure to one of underlying assets and updates it.
     * @param asset The contract address of the asset.
     * @param exposureAsset The total exposure to an asset.
     * @param conversionRate The conversion rate of the asset to the underlying asset.
     * @param index The index of the underlying asset in assetToInformation[asset].underlyingAssets.
     * @return exposureAssetToUnderlyingAsset The updated amount of exposure to the asset's underlying asset.
     * @return deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure to the asset's underlying asset since last update.
     */
    function _getUnderlyingAssetExposures(address asset, uint256 exposureAsset, uint256 conversionRate, uint8 index)
        internal
        returns (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset)
    {
        // Calculate the total exposure of the asset to a underlying asset.
        exposureAssetToUnderlyingAsset = exposureAsset.mulDivDown(conversionRate, 1e18);

        // Calculate the change in exposure to the underlying assets since last interaction.
        deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAsset)
            - int256(uint256(assetToInformation[asset].exposureAssetToUnderlyingAssetsLast[index]));

        // Update "exposureAssetToUnderlyingAssetLast".
        assetToInformation[asset].exposureAssetToUnderlyingAssetsLast[index] = uint128(exposureAssetToUnderlyingAsset);
    }
}
