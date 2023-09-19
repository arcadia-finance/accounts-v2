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
        address underlyingAsset;
        uint128 assetExposureLast;
        uint128 conversionRateLast;
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
    function getAssetInformation(address asset) external view returns (address, uint128, uint128) {
        return (
            assetToInformation[asset].underlyingAsset,
            assetToInformation[asset].assetExposureLast,
            assetToInformation[asset].conversionRateLast
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
        (int256 deltaUnderlyingAssetExposureTotal,) = _getDeltaUnderlyingAssetExposure(asset, int256(amount));

        // Get the USD Value of the total change in exposure to the underlying assets.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value of the delta in exposure by the higher level Pricing Module.
        uint256 deltaUsdExposure = IMainRegistry(mainRegistry).getUsdExposureUnderlyingAssetAfterDeposit(
            assetToInformation[asset].underlyingAsset, 0, deltaUnderlyingAssetExposureTotal
        );

        // Cache usdExposure.
        uint256 usdExposureLast = usdExposure;

        if (deltaUsdExposure >= 0) {
            require(usdExposureLast + deltaUsdExposure <= maxUsdExposure, "APM_IE: Exposure not in limits");
            usdExposure = usdExposureLast + deltaUsdExposure;
            emit UsdExposureChanged(usdExposureLast, usdExposureLast + deltaUsdExposure);
        } else {
            usdExposure = usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0;
            emit UsdExposureChanged(
                usdExposureLast, usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0
            );
        }
    }

    function processIndirectDeposit(address asset, uint256, int256 amount)
        public
        override
        onlyMainReg
        returns (bool primaryFlag, uint256 valueDepositInUsd)
    {
        (int256 deltaUnderlyingAssetExposureTotal, int256 deltaUnderlyingAssetExposureNewDeposit) =
            _getDeltaUnderlyingAssetExposure(asset, amount);

        // Get the USD Value of the total change in exposure to the underlying assets.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value of the delta in exposure by the higher level Pricing Module.
        uint256 deltaUsdExposure = IMainRegistry(mainRegistry).getUsdExposureUnderlyingAssetAfterDeposit(
            assetToInformation[asset].underlyingAsset, 0, deltaUnderlyingAssetExposureTotal
        );

        // Cache usdExposure.
        uint256 usdExposureLast = usdExposure;

        // Calculate the updated USD exposure, and check if it did not exceed the protocols exposure limit.
        if (deltaUnderlyingAssetExposureTotal >= 0) {
            require(usdExposureLast + deltaUsdExposure <= maxUsdExposure, "APM_IE: Exposure not in limits");
            usdExposure = usdExposureLast + deltaUsdExposure;
            emit UsdExposureChanged(usdExposureLast, usdExposureLast + deltaUsdExposure);
        } else {
            usdExposure = usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0;
            emit UsdExposureChanged(
                usdExposureLast, usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0
            );

            // ToDo: use proper signed math library
            deltaUnderlyingAssetExposureTotal = -deltaUnderlyingAssetExposureTotal;
        }

        deltaUnderlyingAssetExposureNewDeposit = deltaUnderlyingAssetExposureNewDeposit >= 0
            ? deltaUnderlyingAssetExposureNewDeposit
            : -deltaUnderlyingAssetExposureNewDeposit;

        // Calculate the USD value of the deposited assets to the higher level Pricing Module.
        // ToDo: use proper signed math library
        valueDepositInUsd = deltaUsdExposure.mulDivDown(
            uint256(deltaUnderlyingAssetExposureNewDeposit), uint256(deltaUnderlyingAssetExposureTotal)
        );

        return (PRIMARY_FLAG, valueDepositInUsd);
    }

    function processDirectWithdrawal(address asset, uint256, uint256 amount) public override onlyMainReg {
        (int256 deltaUnderlyingAssetExposureTotal,) = _getDeltaUnderlyingAssetExposure(asset, -int256(amount));

        // Get the USD Value of the total change in exposure to the underlying assets.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value of the delta in exposure by the higher level Pricing Module.
        uint256 deltaUsdExposure = IMainRegistry(mainRegistry).getUsdExposureUnderlyingAssetAfterWithdrawal(
            assetToInformation[asset].underlyingAsset, 0, deltaUnderlyingAssetExposureTotal
        );

        // Cache usdExposure.
        uint256 usdExposureLast = usdExposure;

        if (deltaUnderlyingAssetExposureTotal >= 0) {
            require(usdExposureLast + deltaUsdExposure <= type(uint128).max, "APM_IE: Overflow");
            usdExposure = usdExposureLast + deltaUsdExposure;
            emit UsdExposureChanged(usdExposureLast, usdExposureLast + deltaUsdExposure);
        } else {
            usdExposure = usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0;
            emit UsdExposureChanged(
                usdExposureLast, usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0
            );
        }
    }

    function processIndirectWithdrawal(address asset, uint256, int256 amount)
        public
        override
        onlyMainReg
        returns (bool primaryFlag, uint256 valueDepositInUsd)
    {
        (int256 deltaUnderlyingAssetExposureTotal, int256 deltaUnderlyingAssetExposureNewDeposit) =
            _getDeltaUnderlyingAssetExposure(asset, amount);

        // Get the USD Value of the total change in exposure to the underlying assets.
        // If "underlyingAsset" has one or more underlying assets itself, the lower level
        // Pricing Modules will recursively update their respective exposures and return
        // the requested USD value of the delta in exposure by the higher level Pricing Module.
        uint256 deltaUsdExposure = IMainRegistry(mainRegistry).getUsdExposureUnderlyingAssetAfterWithdrawal(
            assetToInformation[asset].underlyingAsset, 0, deltaUnderlyingAssetExposureTotal
        );

        // Cache usdExposure.
        uint256 usdExposureLast = usdExposure;

        // Calculate the updated USD exposure, and check if it did not exceed the protocols exposure limit.
        if (deltaUnderlyingAssetExposureTotal >= 0) {
            usdExposure = usdExposureLast + deltaUsdExposure;
            emit UsdExposureChanged(usdExposureLast, usdExposureLast + deltaUsdExposure);
        } else {
            usdExposure = usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0;
            emit UsdExposureChanged(
                usdExposureLast, usdExposureLast >= deltaUsdExposure ? usdExposureLast - deltaUsdExposure : 0
            );
            // ToDo: use proper signed math library
            deltaUnderlyingAssetExposureTotal = -deltaUnderlyingAssetExposureTotal;
        }

        deltaUnderlyingAssetExposureNewDeposit = deltaUnderlyingAssetExposureNewDeposit >= 0
            ? deltaUnderlyingAssetExposureNewDeposit
            : -deltaUnderlyingAssetExposureNewDeposit;

        // Calculate the USD value of the deposited assets to the higher level Pricing Module.
        // ToDo: use proper signed math library
        valueDepositInUsd = deltaUsdExposure.mulDivDown(
            uint256(deltaUnderlyingAssetExposureNewDeposit), uint256(deltaUnderlyingAssetExposureTotal)
        );

        return (PRIMARY_FLAG, valueDepositInUsd);
    }

    function _getDeltaUnderlyingAssetExposure(address asset, int256 amount)
        internal
        returns (int256 deltaUnderlyingAssetExposureTotal, int256 deltaUnderlyingAssetExposureNewDeposit)
    {
        // Get the current flashloan resistant Conversion rate from the asset to it's underlying asset(s) (with 18 decimals precision).
        uint256 conversionRateNew = _getConversionRate(asset);
        // Cache the old Conversion rate and overwrite it with current rate.
        uint256 conversionRateLast = assetToInformation[asset].conversionRateLast;
        assetToInformation[asset].conversionRateLast = uint128(conversionRateNew);

        // Cache the old exposure to the asset.
        uint256 assetExposureLast = assetToInformation[asset].assetExposureLast;

        // Calculate the change in exposure to the underlying assets due to the deposit (positive number is an increase in underlying assets).
        // ToDo: Use signed arithmetic library
        if (amount > 0) {
            deltaUnderlyingAssetExposureNewDeposit = int256(uint256(amount).mulDivDown(conversionRateNew, 1e18));
            // ToDo: safecast?
            assetToInformation[asset].assetExposureLast = uint128(assetExposureLast + uint256(amount));
        } else {
            // ToDo: is caching uint256(-amount) cheaper?
            deltaUnderlyingAssetExposureNewDeposit = -int256(uint256(-amount).mulDivDown(conversionRateNew, 1e18));
            assetToInformation[asset].assetExposureLast =
                assetExposureLast >= uint256(-amount) ? uint128(assetExposureLast - uint256(-amount)) : 0;
        }

        // Calculate the change in exposure to the underlying assets due to the change in Conversion Rate
        // since the last interaction with the asset (positive number is an increase in underlying assets).
        int256 deltaUnderlyingAssetExposureLast;
        if (conversionRateNew >= conversionRateLast) {
            deltaUnderlyingAssetExposureLast =
                int256(assetExposureLast.mulDivDown(conversionRateNew - conversionRateLast, 1e18));
        } else {
            deltaUnderlyingAssetExposureLast =
                -int256(assetExposureLast.mulDivDown(conversionRateLast - conversionRateNew, 1e18));
        }

        // Calculate the total change in exposure to the underlying assets.
        deltaUnderlyingAssetExposureTotal = deltaUnderlyingAssetExposureLast + deltaUnderlyingAssetExposureNewDeposit;
    }
}
