/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DerivedPricingModule } from "./DerivedPricingModuleOptionThomas.sol";
import { IMainRegistry } from "./interfaces/IMainRegistryOptionThomas.sol";
import { IERC4626 } from "../interfaces/IERC4626.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title Mocked Pricing Module for ERC4626 tokens
 * @author Pragma Labs
 * @notice The StandardERC4626Registry stores pricing logic and basic information for ERC4626 tokens for which the underlying assets have direct price feed.
 * @dev No end-user should directly interact with the StandardERC4626Registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract ERC4626PricingModule is DerivedPricingModule {
    using FixedPointMathLib for uint256;

    mapping(address => AssetInformation) public assetToInformation;

    struct AssetInformation {
        uint128 exposureAssetLast;
        uint128 usdValueExposureAssetLast;
        address underlyingAsset;
        uint128 exposureAssetToUnderlyingAssetLast;
    }

    event UsdExposureChanged(uint256 oldExposure, uint256 newExposure);

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
     * @param oracleHub_ The address of the Oracle-Hub.
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the Accounts.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        DerivedPricingModule(mainRegistry_, oracleHub_, assetType_, msg.sender)
    { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the ATokenPricingModule.
     * @param asset The contract address of the asset
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     * @dev Assets can't have more than 18 decimals.
     */
    function addAsset(address asset) external onlyOwner {
        address underlyingAsset = address(IERC4626(asset).asset());

        require(!inPricingModule[asset], "PM4626_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        assetToInformation[asset].underlyingAsset = underlyingAsset;

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /**
     * @notice Returns the information that is stored in the Sub-registry for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     */
    function getAssetInformation(address asset) external view returns (uint128, uint128, address, uint128) {
        return (
            assetToInformation[asset].exposureAssetLast,
            assetToInformation[asset].usdValueExposureAssetLast,
            assetToInformation[asset].underlyingAsset,
            assetToInformation[asset].exposureAssetToUnderlyingAssetLast
        );
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - assetAddress: The contract address of the asset
     * - assetId: Since ERC4626 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of Shares, ERC4626 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return collateralFactor The Collateral Factor of the asset
     * @return liquidationFactor The Liquidation Factor of the asset
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in StandardERC4626Registry is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        address asset = getValueInput.asset;
        uint256 conversionRate = _getConversionRate(asset);

        getValueInput.asset = assetToInformation[asset].underlyingAsset;
        getValueInput.assetAmount = getValueInput.assetAmount.mulDivDown(conversionRate, 1e18);

        (valueInUsd, collateralFactor, liquidationFactor) =
            IMainRegistry(mainRegistry).getValueUnderlyingAsset(getValueInput);
    }

    function _getConversionRate(address asset) internal view returns (uint256 conversionRate) {
        conversionRate = IERC4626(asset).convertToAssets(1e18);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address asset, uint256, uint256 amount) public override onlyMainReg {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, int256(amount));

        // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
        uint256 conversionRate = _getConversionRate(asset);

        // Calculate and update the total exposure, and the delta since last interaction, of "Asset" to "Underlying Asset".
        (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) =
            _getUnderlyingAssetExposures(asset, exposureAsset, conversionRate);

        // Get the USD Value of the total exposure of "Asset" for "Underlying Asset.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value to this Pricing Module.
        uint256 usdValueExposureAssetToUnderlyingAsset = IMainRegistry(mainRegistry)
            .getUsdExposureUnderlyingAssetAfterDeposit(
            assetToInformation[asset].underlyingAsset,
            0,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        // For assets with only one Underlying asset, "usdValueExposureAsset" equals "usdValueExposureAssetToUnderlyingAsset"
        uint256 usdValueExposureAsset = usdValueExposureAssetToUnderlyingAsset;

        // Cache usdValueExposureAssetLast and update usdValueExposureAssetLast.
        uint256 usdValueExposureAssetLast = assetToInformation[asset].usdValueExposureAssetLast;
        assetToInformation[asset].usdValueExposureAssetLast = uint128(usdValueExposureAsset);

        // Cache usdExposureProtocol.
        uint256 usdExposureProtocolLast = usdExposureProtocol;

        // Update usdExposureProtocolLast.
        if (usdValueExposureAsset >= usdValueExposureAssetLast) {
            require(
                usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast <= maxUsdExposureProtocol,
                "APM_IE: Exposure not in limits"
            );
            usdExposureProtocol = usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast;
        } else {
            usdExposureProtocol = usdExposureProtocolLast > usdValueExposureAssetLast - usdValueExposureAsset
                ? usdExposureProtocolLast - usdValueExposureAsset + usdValueExposureAssetLast
                : 0;
        }

        emit UsdExposureChanged(usdExposureProtocolLast, usdExposureProtocol);
    }

    function processIndirectDeposit(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, deltaExposureUpperAssetToAsset);

        // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
        uint256 conversionRate = _getConversionRate(asset);

        // Calculate and update the total exposure, and the delta since last interaction, of "Asset" to "Underlying Asset".
        (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) =
            _getUnderlyingAssetExposures(asset, exposureAsset, conversionRate);

        // Get the USD Value of the total exposure of "Asset" for "Underlying Asset.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value to this Pricing Module.
        uint256 usdValueExposureAssetToUnderlyingAsset = IMainRegistry(mainRegistry)
            .getUsdExposureUnderlyingAssetAfterDeposit(
            assetToInformation[asset].underlyingAsset,
            0,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        // For assets with only one Underlying asset, "usdValueExposureAsset" equals "usdValueExposureAssetToUnderlyingAsset"
        uint256 usdValueExposureAsset = usdValueExposureAssetToUnderlyingAsset;

        // Cache usdValueExposureAssetLast and update usdValueExposureAssetLast.
        uint256 usdValueExposureAssetLast = assetToInformation[asset].usdValueExposureAssetLast;
        assetToInformation[asset].usdValueExposureAssetLast = uint128(usdValueExposureAsset);

        // Cache usdExposureProtocol.
        uint256 usdExposureProtocolLast = usdExposureProtocol;

        // Update usdExposureProtocolLast.
        if (usdValueExposureAsset >= usdValueExposureAssetLast) {
            require(
                usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast <= maxUsdExposureProtocol,
                "APM_IE: Exposure not in limits"
            );
            usdExposureProtocol = usdExposureProtocolLast + usdValueExposureAsset - usdValueExposureAssetLast;
        } else {
            usdExposureProtocol = usdExposureProtocolLast > usdValueExposureAssetLast - usdValueExposureAsset
                ? usdExposureProtocolLast - usdValueExposureAsset + usdValueExposureAssetLast
                : 0;
        }

        emit UsdExposureChanged(usdExposureProtocolLast, usdExposureProtocol);

        // Calculate the USD value of the exposure of the Upper Asset to the Underlying asset.
        usdValueExposureUpperAssetToAsset = usdValueExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    function processDirectWithdrawal(address asset, uint256, uint256 amount) public override onlyMainReg {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, -int256(amount));

        // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
        uint256 conversionRate = _getConversionRate(asset);

        // Calculate and update the total exposure, and the delta since last interaction, of "Asset" to "Underlying Asset".
        (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) =
            _getUnderlyingAssetExposures(asset, exposureAsset, conversionRate);

        // Get the USD Value of the total exposure of "Asset" for "Underlying Asset.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value to this Pricing Module.
        uint256 usdValueExposureAssetToUnderlyingAsset = IMainRegistry(mainRegistry)
            .getUsdExposureUnderlyingAssetAfterWithdrawal(
            assetToInformation[asset].underlyingAsset,
            0,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        // For assets with only one Underlying asset, "usdValueExposureAsset" equals "usdValueExposureAssetToUnderlyingAsset"
        uint256 usdValueExposureAsset = usdValueExposureAssetToUnderlyingAsset;

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

    function processIndirectWithdrawal(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Calculate and update the new exposure to "Asset".
        uint256 exposureAsset = _getExposureAsset(asset, deltaExposureUpperAssetToAsset);

        // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
        uint256 conversionRate = _getConversionRate(asset);

        // Calculate and update the total exposure, and the delta since last interaction, of "Asset" to "Underlying Asset".
        (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset) =
            _getUnderlyingAssetExposures(asset, exposureAsset, conversionRate);

        // Get the USD Value of the total exposure of "Asset" for "Underlying Asset.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value to this Pricing Module.
        uint256 usdValueExposureAssetToUnderlyingAsset = IMainRegistry(mainRegistry)
            .getUsdExposureUnderlyingAssetAfterWithdrawal(
            assetToInformation[asset].underlyingAsset,
            0,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );

        // For assets with only one Underlying asset, "usdValueExposureAsset" equals "usdValueExposureAssetToUnderlyingAsset"
        uint256 usdValueExposureAsset = usdValueExposureAssetToUnderlyingAsset;

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

        // Calculate the USD value of the exposure of the Upper Asset to the Underlying asset.
        if (exposureUpperAssetToAsset == exposureAsset) {
            // Avoid devide by zero if both are 0.
            usdValueExposureUpperAssetToAsset = usdValueExposureAsset;
        } else {
            usdValueExposureUpperAssetToAsset =
                usdValueExposureAsset.mulDivDown(exposureUpperAssetToAsset, exposureAsset);
        }

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

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

    function _getUnderlyingAssetExposures(address asset, uint256 exposureAsset, uint256 conversionRate)
        internal
        returns (uint256 exposureAssetToUnderlyingAsset, int256 deltaExposureAssetToUnderlyingAsset)
    {
        // Calculate the total exposure of the asset to a underlying asset.
        exposureAssetToUnderlyingAsset = exposureAsset.mulDivDown(conversionRate, 1e18);

        // Calculate the change in exposure to the underlying assets since last interaction.
        deltaExposureAssetToUnderlyingAsset = int256(exposureAssetToUnderlyingAsset)
            - int256(uint256(assetToInformation[asset].exposureAssetToUnderlyingAssetLast));

        // Update "exposureAssetToUnderlyingAssetLast".
        assetToInformation[asset].exposureAssetToUnderlyingAssetLast = uint128(exposureAssetToUnderlyingAsset);
    }
}
