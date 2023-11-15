/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { BitPackingLib } from "./libraries/BitPackingLib.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IDerivedAssetModule } from "./interfaces/IDerivedAssetModule.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { IOracleModule } from "./interfaces/IOracleModule.sol";
import { IAssetModule } from "./interfaces/IAssetModule.sol";
import { IPrimaryAssetModule } from "./interfaces/IPrimaryAssetModule.sol";
import { ICreditor } from "./interfaces/ICreditor.sol";
import { RegistryGuardian } from "./guardians/RegistryGuardian.sol";
import { RiskModule } from "./RiskModule.sol";

/**
 * @title Main Asset registry
 * @author Pragma Labs
 * @notice The Registry has a number of responsibilities, all related to the management of asset and oracles:
 *  - It stores the mapping between assets and their respective asset-modules.
 *  - It stores the mapping between oracles and their respective oracle-modules.
 *  - It orchestrates the pricing of a basket of assets in a single unit of account.
 *  - It orchestrates deposits and withdrawals of an Account per certain Creditor.
 *  - It manages the risk parameters of all assets per Creditor.
 *  - It manages the action handlers.
 */
contract Registry is IRegistry, RegistryGuardian {
    using FixedPointMathLib for uint256;
    using BitPackingLib for bytes32;

    /* //////////////////////////////////////////////////////////////
                               CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Contract address of the Factory.
    address public immutable FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Counter with the number of oracles in the Registry.
    uint256 internal oracleCounter;

    // Map registry => flag.
    mapping(address => bool) public inRegistry;
    // Map assetModule => flag.
    mapping(address => bool) public isAssetModule;
    // Map oracleModule => flag.
    mapping(address => bool) public isOracleModule;
    // Map action => flag.
    mapping(address => bool) public isActionAllowed;
    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToAssetInformation;
    // Map oracle identifier => oracleModule.
    mapping(uint256 => address) internal oracleToOracleModule;
    // Map creditor to minimum usd value of assets that are taken into account.
    mapping(address => uint256) public minUsdValueCreditor;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        // Identifier for the token standard of the asset.
        uint96 assetType;
        // Contract address of the module that can price the specific asset.
        address assetModule;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AllowedActionSet(address indexed action, bool allowed);
    event AssetModuleAdded(address assetModule);
    event OracleModuleAdded(address oracleModule);
    event AssetAdded(address indexed assetAddress, address indexed assetModule, uint8 assetType);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only Asset Modules can call functions with this modifier.
     */
    modifier onlyAssetModule() {
        require(isAssetModule[msg.sender], "MR: Only AssetMod.");
        _;
    }

    /**
     * @dev Only Oracle Modules can call functions with this modifier.
     */
    modifier onlyOracleModule() {
        require(isOracleModule[msg.sender], "MR: Only OracleMod.");
        _;
    }

    /**
     * @dev Only Accounts can call functions with this modifier.
     */
    modifier onlyAccount() {
        require(IFactory(FACTORY).isAccount(msg.sender), "MR: Only Accounts.");
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Factory.
     */
    constructor(address factory) {
        FACTORY = factory;
    }

    /* ///////////////////////////////////////////////////////////////
                        EXTERNAL CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets an allowance of an action handler.
     * @param action The contract address of the action handler.
     * @param allowed Bool to indicate its status.
     * @dev Can only be called by owner.
     */
    function setAllowedAction(address action, bool allowed) external onlyOwner {
        isActionAllowed[action] = allowed;

        emit AllowedActionSet(action, allowed);
    }

    /* ///////////////////////////////////////////////////////////////
                        MODULE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new Asset Module to the Registry.
     * @param assetModule The contract address of the Asset Module.
     */
    function addAssetModule(address assetModule) external onlyOwner {
        require(!isAssetModule[assetModule], "MR_APM: AssetMod. not unique");
        isAssetModule[assetModule] = true;

        emit AssetModuleAdded(assetModule);
    }

    /**
     * @notice Adds a new Oracle Module to the Registry.
     * @param oracleModule The contract address of the Oracle Module.
     */
    function addOracleModule(address oracleModule) external onlyOwner {
        require(!isOracleModule[oracleModule], "MR_AOM: OracleMod. not unique");
        isOracleModule[oracleModule] = true;

        emit OracleModuleAdded(oracleModule);
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
        address assetModule = assetToAssetInformation[asset].assetModule;

        if (assetModule == address(0)) return false;

        return IAssetModule(assetToAssetInformation[asset].assetModule).isAllowed(asset, assetId);
    }

    /**
     * @notice Adds a new asset to the Registry.
     * @param assetAddress The contract address of the asset.
     * @param assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * @dev Assets that are already in the registry cannot be overwritten,
     * as that would make it possible for devs to change the asset pricing.
     */
    function addAsset(address assetAddress, uint256 assetType) external onlyAssetModule {
        require(!inRegistry[assetAddress], "MR_AA: Asset already in registry");
        require(assetType <= type(uint96).max, "MR_AA: Invalid AssetType");

        inRegistry[assetAddress] = true;
        assetToAssetInformation[assetAddress] =
            AssetInformation({ assetType: uint96(assetType), assetModule: msg.sender });

        emit AssetAdded(assetAddress, msg.sender, uint8(assetType));
    }

    /* ///////////////////////////////////////////////////////////////
                        ORACLE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new oracle to the Registry.
     * @return oracleId Unique identifier of the oracle.
     */
    function addOracle() external onlyOracleModule returns (uint256 oracleId) {
        // New oracle get.
        oracleId = oracleCounter;

        oracleToOracleModule[oracleId] = msg.sender;

        unchecked {
            oracleCounter = oracleId + 1;
        }
    }

    /**
     * @notice Verifies whether a sequence of oracles complies with a predetermined set of criteria.
     * @param oracleSequence The sequence of the oracles to price a certain asset in USD,
     * packed in a single bytes32 object.
     * @return A boolean, indicating if the sequence complies with the set of criteria.
     * @dev The following checks are performed:
     * - The oracle must be previously added to the Registry and must still be active.
     * - ToDo The first asset of the first oracle must be the asset being priced.
     * - The last asset of all oracles must be equal to the first asset of the next oracle.
     * - The last asset of the last oracle must be USD.
     */
    function checkOracleSequence(bytes32 oracleSequence) external view returns (bool) {
        (bool[] memory baseToQuoteAsset, uint256[] memory oracles) = oracleSequence.unpack();
        uint256 length = oracles.length;
        require(length > 0, "MR_COS: Min 1 Oracle");
        // Length can be maximally 3, but no need to explicitly check it.
        // BitPackingLib.unpack() can maximally return arrays of length 3.

        address oracleModule;
        bytes16 baseAsset;
        bytes16 quoteAsset;
        bytes16 lastAsset;
        for (uint256 i; i < length;) {
            oracleModule = oracleToOracleModule[oracles[i]];

            if (!IOracleModule(oracleModule).isActive(oracles[i])) return false;
            (baseAsset, quoteAsset) = IOracleModule(oracleModule).assetPair(oracles[i]);

            if (i == 0) {
                // ToDo: check if first asset matches the asset to be priced?
                lastAsset = baseToQuoteAsset[i] ? quoteAsset : baseAsset;
            } else {
                // Last asset of an oracle must match with the first asset of the next oracle.
                if (baseToQuoteAsset[i]) {
                    if (lastAsset != baseAsset) return false;
                    lastAsset = quoteAsset;
                } else {
                    if (lastAsset != quoteAsset) return false;
                    lastAsset = baseAsset;
                }
            }
            // Last asset in the sequence must end with "USD".
            if (i == length - 1 && lastAsset != "USD") return false;

            unchecked {
                ++i;
            }
        }

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors per asset for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @return collateralFactors Array of the collateral factors of the assets for the creditor, 4 decimals precision.
     * @return liquidationFactors Array of the liquidation factors of the assets for the creditor, 4 decimals precision.
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
            (collateralFactors[i], liquidationFactors[i]) = IAssetModule(
                assetToAssetInformation[assetAddresses[i]].assetModule
            ).getRiskFactors(creditor, assetAddresses[i], assetIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets the risk parameters for a primary asset for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param maxExposure The maximum exposure of a creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the creditor, 4 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the creditor, 4 decimals precision.
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
        require(msg.sender == ICreditor(creditor).riskManager(), "MR_SRPPA: Not Authorized");

        IPrimaryAssetModule(assetToAssetInformation[asset].assetModule).setRiskParameters(
            creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
    }

    /**
     * @notice Sets the risk parameters for the protocol of the Derived Asset Module for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param assetModule The contract address of the derived asset-module.
     * @param maxUsdExposureProtocol The maximum usd exposure of the protocol for each creditor,
     * denominated in USD with 18 decimals precision.
     * @param riskFactor The risk factor of the asset for the creditor, 4 decimals precision.
     */
    function setRiskParametersOfDerivedAssetModule(
        address creditor,
        address assetModule,
        uint128 maxUsdExposureProtocol,
        uint16 riskFactor
    ) external {
        require(msg.sender == ICreditor(creditor).riskManager(), "MR_SRPDPM: Not Authorized");

        IDerivedAssetModule(assetModule).setRiskParameters(creditor, maxUsdExposureProtocol, riskFactor);
    }

    /**
     * @notice Sets the minimum usd value of assets that are taken into account for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param minUsdValue The minimum usd value of assets that are taken into account for the creditor,
     * denominated in USD with 18 decimals precision.
     * @dev This feature is to prevent dust from being taken into account and preventing liquidations.
     */
    function setMinUsdValueCreditor(address creditor, uint256 minUsdValue) external {
        require(msg.sender == ICreditor(creditor).riskManager(), "MR_SMUVC: Not Authorized");

        minUsdValueCreditor[creditor] = minUsdValue;
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
     * @dev increaseExposure in the asset module checks and updates the exposure for each asset and underlying asset.
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

            IAssetModule(assetToAssetInformation[assetAddress].assetModule).processDirectDeposit(
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
     * @dev batchProcessWithdrawal in the asset module updates the exposure for each asset and underlying asset.
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

            IAssetModule(assetToAssetInformation[assetAddress].assetModule).processDirectWithdrawal(
                creditor, assetAddress, assetIds[i], amounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice This function is called by asset modules of non-primary assets
     * in order to update the exposure of an underlying asset after a deposit.
     * @param creditor The contract address of the creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset
     * since the last interaction.
     * @return usdExposureAssetToUnderlyingAsset The Usd value of the exposure of the asset to its underlying asset,
     * 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterDeposit(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external onlyAssetModule returns (uint256 usdExposureAssetToUnderlyingAsset) {
        (, usdExposureAssetToUnderlyingAsset) = IAssetModule(assetToAssetInformation[underlyingAsset].assetModule)
            .processIndirectDeposit(
            creditor,
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    /**
     * @notice This function is called by asset modules of non-primary assets
     * in order to update the exposure of an underlying asset after a withdrawal.
     * @param creditor The contract address of the creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset
     * since the last interaction.
     * @return usdExposureAssetToUnderlyingAsset The Usd value of the exposure of the asset to its underlying asset,
     * 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external onlyAssetModule returns (uint256 usdExposureAssetToUnderlyingAsset) {
        (, usdExposureAssetToUnderlyingAsset) = IAssetModule(assetToAssetInformation[underlyingAsset].assetModule)
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
     * @notice Returns the rate of a certain asset in USD.
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     * @return rate The USD rate of an asset, 18 decimals precision.
     * @dev The oracle rate expresses how much USD (18 decimals precision) is required
     * to buy 1 unit of the asset.
     */
    function getRateInUsd(bytes32 oracleSequence) external view returns (uint256 rate) {
        (bool[] memory baseToQuoteAsset, uint256[] memory oracles) = oracleSequence.unpack();

        rate = 1e18; // Scalar 1 with 18 decimals (The internal precision).

        uint256 length = oracles.length;
        for (uint256 i; i < length;) {
            // Each Oracle has a fixed BaseAsset and quote asset.
            // The oracle-rate expresses how much units of the QuoteAsset (18 decimals precision) are required
            // to buy 1 unit of the BaseAsset.
            if (baseToQuoteAsset[i]) {
                // "Normal direction" (how much of the QuoteAsset is required to buy 1 unit of the BaseAsset).
                // -> Multiply with the oracle-rate.
                rate = rate.mulDivDown(IOracleModule(oracleToOracleModule[oracles[i]]).getRate(oracles[i]), 1e18);
            } else {
                // "Inverse direction" (how much of the BaseAsset is required to buy 1 unit of the QuoteAsset).
                // -> Divide by the oracle-rate.
                rate = rate.mulDivDown(1e18, IOracleModule(oracleToOracleModule[oracles[i]]).getRate(oracles[i]));
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates the usd value of an asset.
     * @param creditor The contract address of the creditor.
     * @param assets Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @return valuesAndRiskFactors The values of the assets denominated in USD () with 18 Decimals precision)
     * and the corresponding risk factors for each asset for the given creditor.
     */
    function getValuesInUsd(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public view returns (RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        uint256 length = assets.length;
        valuesAndRiskFactors = new RiskModule.AssetValueAndRiskFactors[](length);

        uint256 minUsdValue = minUsdValueCreditor[creditor];
        for (uint256 i; i < length;) {
            (
                valuesAndRiskFactors[i].assetValue,
                valuesAndRiskFactors[i].collateralFactor,
                valuesAndRiskFactors[i].liquidationFactor
            ) = IAssetModule(assetToAssetInformation[assets[i]].assetModule).getValue(
                creditor, assets[i], assetIds[i], assetAmounts[i]
            );
            // If asset value is too low, set to zero.
            // This is done to prevent dust attacks which may make liquidations unprofitable.
            if (valuesAndRiskFactors[i].assetValue < minUsdValue) valuesAndRiskFactors[i].assetValue = 0;

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
     * @dev Only fungible tokens can be used as baseCurrency.
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
            (uint256 rateBaseCurrencyToUsd,,) = IAssetModule(assetToAssetInformation[baseCurrency].assetModule).getValue(
                creditor, baseCurrency, 0, 1e18
            );

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
     * @dev Only fungible tokens can be used as baseCurrency.
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
     * @dev Only fungible tokens can be used as baseCurrency.
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
     * @dev Only fungible tokens can be used as baseCurrency.
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
        (uint256 rateBaseCurrencyToUsd,,) =
            IAssetModule(assetToAssetInformation[baseCurrency].assetModule).getValue(address(0), baseCurrency, 0, 1e18);

        // "liquidationValue" is the usd value of the assets with 18 decimals precision.
        // "rateBaseCurrencyToUsd" is the usd value of 10 ** 18 tokens of numeraire with 18 decimals precision.
        // To get the value of the asset denominated in the numeraire, we have to multiply usd value of "assetValue" with 10**18
        // and divide by "rateBaseCurrencyToUsd".
        valueInBaseCurrency = valueInUsd.mulDivDown(1e18, rateBaseCurrencyToUsd);
    }
}
