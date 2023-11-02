/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IChainLinkData } from "./interfaces/IChainLinkData.sol";
import { IDerivedPricingModule } from "./interfaces/IDerivedPricingModule.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IPricingModule } from "./interfaces/IPricingModule.sol";
import { IPrimaryPricingModule } from "./interfaces/IPrimaryPricingModule.sol";
import { ITrustedCreditor } from "./interfaces/ITrustedCreditor.sol";
import { MainRegistryGuardian } from "./guardians/MainRegistryGuardian.sol";
import { RiskModule } from "./RiskModule.sol";

/**
 * @title Main Asset registry
 * @author Pragma Labs
 * @notice The Main Registry stores basic information for each token that can, or could at some point, be deposited in the Accounts.
 * @dev No end-user should directly interact with the Main Registry, only Accounts, Pricing Modules or the contract owner.
 */
contract MainRegistry is IMainRegistry, MainRegistryGuardian {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Contract address of the Factory.
    address public immutable factory;

    // Array with all the contract addresses of Pricing Modules.
    address[] public pricingModules;
    // Array with all the contract addresses of Tokens that can be Priced.
    address[] public assetsInMainRegistry;

    // Map mainRegistry => flag.
    mapping(address => bool) public inMainRegistry;
    // Map pricingModule => flag.
    mapping(address => bool) public isPricingModule;
    // Map action => flag.
    mapping(address => bool) public isActionAllowed;
    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToAssetInformation;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        uint96 assetType; // Identifier for the token standard of the asset.
        address pricingModule; // Contract address of the module that can price the specific asset.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AllowedActionSet(address indexed action, bool allowed);
    event PricingModuleAdded(address pricingModule);
    event AssetAdded(address indexed assetAddress, address indexed pricingModule, uint8 assetType);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only Pricing Modules can call functions with this modifier.
     */
    modifier onlyPricingModule() {
        require(isPricingModule[msg.sender], "MR: Only PriceMod.");
        _;
    }

    /**
     * @dev Only Accounts can call functions with this modifier.
     * @dev Cannot be called via delegate calls.
     */
    modifier onlyAccount() {
        require(IFactory(factory).isAccount(msg.sender), "MR: Only Accounts.");
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory_ The contract address of the Factory.
     */
    constructor(address factory_) {
        factory = factory_;
    }

    /* ///////////////////////////////////////////////////////////////
                        EXTERNAL CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets an allowed action handler.
     * @param action The address of the action handler.
     * @param allowed Bool to indicate its status.
     * @dev Can only be called by owner.
     */
    function setAllowedAction(address action, bool allowed) external onlyOwner {
        isActionAllowed[action] = allowed;

        emit AllowedActionSet(action, allowed);
    }

    /* ///////////////////////////////////////////////////////////////
                        PRICE MODULE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new Pricing Module to the Main Registry.
     * @param pricingModule The contract address of the Pricing Module.
     */
    function addPricingModule(address pricingModule) external onlyOwner {
        require(!isPricingModule[pricingModule], "MR_APM: PriceMod. not unique");
        isPricingModule[pricingModule] = true;
        pricingModules.push(pricingModule);

        emit PricingModuleAdded(pricingModule);
    }

    /* ///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) external view returns (bool) {
        address pricingModule = assetToAssetInformation[asset].pricingModule;

        if (pricingModule == address(0)) {
            return false;
        } else {
            return IPricingModule(assetToAssetInformation[asset].pricingModule).isAllowed(asset, assetId);
        }
    }

    /**
     * @notice Adds a new asset to the Main Registry.
     * @param assetAddress The contract address of the asset.
     * @param assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @dev Assets that are already in the mainRegistry cannot be overwritten,
     * as that would make it possible for devs to change the asset pricing.
     */
    function addAsset(address assetAddress, uint256 assetType) external onlyPricingModule {
        require(!inMainRegistry[assetAddress], "MR_AA: Asset already in mainreg");
        require(assetType <= type(uint96).max, "MR_AA: Invalid AssetType");

        inMainRegistry[assetAddress] = true;
        assetsInMainRegistry.push(assetAddress);
        assetToAssetInformation[assetAddress] =
            AssetInformation({ assetType: uint96(assetType), pricingModule: msg.sender });

        emit AssetAdded(assetAddress, msg.sender, uint8(assetType));
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors per asset for a creditor.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @return collateralFactors Array of the collateral factors of the assets for the creditor, 2 decimals precision.
     * @return liquidationFactors Array of the liquidation factors of the assets for the creditor, 2 decimals precision.
     */
    function getRiskFactors(address creditor, address[] calldata assetAddresses, uint256[] calldata assetIds)
        external
        view
        returns (uint16[] memory collateralFactors, uint16[] memory liquidationFactors)
    {
        uint256 length = assetAddresses.length;
        collateralFactors = new uint16[](length);
        liquidationFactors = new uint16[](length);
        for (uint256 i; i < length;) {
            (collateralFactors[i], liquidationFactors[i]) = IPricingModule(
                assetToAssetInformation[assetAddresses[i]].pricingModule
            ).getRiskFactors(creditor, assetAddresses[i], assetIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets the risk parameters for a primary asset.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param maxExposure The maximum exposure of a creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the creditor, 2 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the creditor, 2 decimals precision.
     * @dev Any creditor can set risk parameters for any asset, does not have any influence on risk parameters
     * set by other creditors.
     */
    function setRiskParametersOfPrimaryAsset(
        address creditor,
        address asset,
        uint256 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external {
        require(msg.sender == ITrustedCreditor(creditor).riskManager(), "MR_SRPPA: Not Authorized");

        IPrimaryPricingModule(assetToAssetInformation[asset].pricingModule).setRiskParameters(
            creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
    }

    /**
     * @notice Sets the risk parameters of the Protocol for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param pricingModule The contract address of the derived pricing-module.
     * @param maxUsdExposureProtocol The maximum usd exposure of the protocol for each creditor, denominated in USD with 18 decimals precision.
     * @param riskFactor The risk factor of the asset for the creditor, 2 decimals precision.
     */
    function setRiskParametersOfDerivedPricingModule(
        address creditor,
        address pricingModule,
        uint128 maxUsdExposureProtocol,
        uint16 riskFactor
    ) external {
        require(msg.sender == ITrustedCreditor(creditor).riskManager(), "MR_SRPDPM: Not Authorized");

        IDerivedPricingModule(pricingModule).setRiskParameters(creditor, maxUsdExposureProtocol, riskFactor);
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Batch deposit multiple assets.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @dev increaseExposure in the pricing module checks whether it's allowlisted and updates the exposure.
     */
    function batchProcessDeposit(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external whenDepositNotPaused onlyAccount returns (uint256[] memory assetTypes) {
        uint256 addressesLength = assetAddresses.length;
        require(addressesLength == assetIds.length && addressesLength == amounts.length, "MR_BPD: LENGTH_MISMATCH");

        address assetAddress;
        assetTypes = new uint256[](addressesLength);
        for (uint256 i; i < addressesLength;) {
            assetAddress = assetAddresses[i];
            assetTypes[i] = assetToAssetInformation[assetAddress].assetType;

            IPricingModule(assetToAssetInformation[assetAddress].pricingModule).processDirectDeposit(
                creditor, assetAddress, assetIds[i], amounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Batch withdraw multiple assets.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @dev batchProcessWithdrawal in the pricing module updates the exposure.
     */
    function batchProcessWithdrawal(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external whenWithdrawNotPaused onlyAccount returns (uint256[] memory assetTypes) {
        uint256 addressesLength = assetAddresses.length;
        require(addressesLength == assetIds.length && addressesLength == amounts.length, "MR_BPW: LENGTH_MISMATCH");

        address assetAddress;
        assetTypes = new uint256[](addressesLength);
        for (uint256 i; i < addressesLength;) {
            assetAddress = assetAddresses[i];
            assetTypes[i] = assetToAssetInformation[assetAddress].assetType;

            IPricingModule(assetToAssetInformation[assetAddress].pricingModule).processDirectWithdrawal(
                creditor, assetAddress, assetIds[i], amounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to update the exposure of an underlying asset after a deposit.
     * @param creditor The contract address of the creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset since the last interaction.
     * @return usdExposureAssetToUnderlyingAsset The Usd value of the exposure of the asset to the underlying asset, 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterDeposit(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external onlyPricingModule returns (uint256 usdExposureAssetToUnderlyingAsset) {
        (, usdExposureAssetToUnderlyingAsset) = IPricingModule(assetToAssetInformation[underlyingAsset].pricingModule)
            .processIndirectDeposit(
            creditor,
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to update the exposure of an underlying asset after a withdrawal.
     * @param creditor The contract address of the creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset since the last interaction.
     * @return usdExposureAssetToUnderlyingAsset The Usd value of the exposure of the asset to the underlying asset, 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external onlyPricingModule returns (uint256 usdExposureAssetToUnderlyingAsset) {
        (, usdExposureAssetToUnderlyingAsset) = IPricingModule(assetToAssetInformation[underlyingAsset].pricingModule)
            .processIndirectWithdrawal(
            creditor,
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    /* ///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Calculates the usd value of an asset.
     * @param creditor The contract address of the creditor.
     * @param assets Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The value of the asset denominated in USD, with 18 Decimals precision.
     */
    function getValuesInUsd(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public view returns (RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        uint256 length = assets.length;
        valuesAndRiskFactors = new RiskModule.AssetValueAndRiskFactors[](length);

        for (uint256 i; i < length;) {
            (
                valuesAndRiskFactors[i].assetValue,
                valuesAndRiskFactors[i].collateralFactor,
                valuesAndRiskFactors[i].liquidationFactor
            ) = IPricingModule(assetToAssetInformation[assets[i]].pricingModule).getValue(
                creditor, assets[i], assetIds[i], assetAmounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates the values per asset, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The array of values per assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the baseCurrency, since getValue()-call will revert for unknown assets.
     */
    function getValuesInBaseCurrency(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        valuesAndRiskFactors = getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        // Convert the usd-vales to values in BaseCurrency if the BaseCurrency is different from USD (0-address).
        if (baseCurrency != address(0)) {
            // We use the USD price per 10^18 tokens instead of the price per token to guarantee sufficient precision.
            (uint256 rateBaseCurrencyToUsd,,) = IPricingModule(assetToAssetInformation[baseCurrency].pricingModule)
                .getValue(creditor, baseCurrency, 0, 1e18);

            uint256 length = assetAddresses.length;
            for (uint256 i; i < length;) {
                // "valuesAndRiskFactors.assetValue" is the usd value of the asset with 18 decimals precision.
                // "rateBaseCurrencyToUsd" is the usd value of 10 ** 18 tokens of numeraire with 18 decimals precision.
                // To get the asset value denominated in the numeraire, we have to multiply usd value of "assetValue" with 10**18
                // and divide by "rateBaseCurrencyToUsd".
                valuesAndRiskFactors[i].assetValue =
                    valuesAndRiskFactors[i].assetValue.mulDivDown(1e18, rateBaseCurrencyToUsd);

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Calculates the combined value of a combination of assets, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return assetValue The combined value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the baseCurrency, since getValue()-call will revert for unknown assets.
     */
    function getTotalValue(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256 assetValue) {
        RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        uint256 length = assetAddresses.length;
        for (uint256 i = 0; i < length;) {
            assetValue += valuesAndRiskFactors[i].assetValue;
            unchecked {
                ++i;
            }
        }

        // Convert the usd-vale to the value in BaseCurrency if the BaseCurrency is different from USD (0-address).
        if (baseCurrency != address(0)) assetValue = _convertValueInUsdToValueInBaseCurrency(baseCurrency, assetValue);
    }

    /**
     * @notice Calculates the collateralValue of a combination of assets, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return collateralValue The collateral value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the baseCurrency, since getValue()-call will revert for unknown assets.
     * @dev The collateral value is equal to the spot value of the assets,
     * discounted by a haircut (the collateral factor).
     */
    function getCollateralValue(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256 collateralValue) {
        RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        // Calculate the "collateralValue" in Usd with 18 decimals precision.
        collateralValue = RiskModule._calculateCollateralValue(valuesAndRiskFactors);

        // Convert the usd-vale to the value in BaseCurrency if the BaseCurrency is different from USD (0-address).
        if (baseCurrency != address(0)) {
            collateralValue = _convertValueInUsdToValueInBaseCurrency(baseCurrency, collateralValue);
        }
    }

    /**
     * @notice Calculates the getLiquidationValue of a combination of assets, denominated in a given BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return liquidationValue The liquidation value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the baseCurrency, since getValue()-call will revert for unknown assets.
     * @dev The liquidation value is equal to the spot value of the assets,
     * discounted by a haircut (the liquidation factor).
     */
    function getLiquidationValue(
        address baseCurrency,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (uint256 liquidationValue) {
        RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        // Calculate the "liquidationValue" in Usd with 18 decimals precision.
        liquidationValue = RiskModule._calculateLiquidationValue(valuesAndRiskFactors);

        // Convert the usd-vale to the value in BaseCurrency if the BaseCurrency is different from USD (0-address).
        if (baseCurrency != address(0)) {
            liquidationValue = _convertValueInUsdToValueInBaseCurrency(baseCurrency, liquidationValue);
        }
    }

    /**
     * @notice Converts a value denominated in Usd to a value denominated in BaseCurrency.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @param valueInUsd The value in Usd, with 18 decimals precision.
     * @return valueInBaseCurrency The value denominated in BaseCurrency.
     */
    function _convertValueInUsdToValueInBaseCurrency(address baseCurrency, uint256 valueInUsd)
        internal
        view
        returns (uint256 valueInBaseCurrency)
    {
        // We use the USD price per 10^18 tokens instead of the price per token to guarantee sufficient precision.
        (uint256 rateBaseCurrencyToUsd,,) = IPricingModule(assetToAssetInformation[baseCurrency].pricingModule).getValue(
            address(0), baseCurrency, 0, 1e18
        );

        // "liquidationValue" is the usd value of the assets with 18 decimals precision.
        // "rateBaseCurrencyToUsd" is the usd value of 10 ** 18 tokens of numeraire with 18 decimals precision.
        // To get the value of the asset denominated in the numeraire, we have to multiply usd value of "assetValue" with 10**18
        // and divide by "rateBaseCurrencyToUsd".
        valueInBaseCurrency = valueInUsd.mulDivDown(1e18, rateBaseCurrencyToUsd);
    }
}
