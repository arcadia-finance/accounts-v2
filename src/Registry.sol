/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { BitPackingLib } from "./libraries/BitPackingLib.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IChainLinkData } from "./interfaces/IChainLinkData.sol";
import { IDerivedAM } from "./interfaces/IDerivedAM.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";
import { IOracleModule } from "./interfaces/IOracleModule.sol";
import { IAssetModule } from "./interfaces/IAssetModule.sol";
import { IPrimaryAM } from "./interfaces/IPrimaryAM.sol";
import { ICreditor } from "./interfaces/ICreditor.sol";
import { RegistryGuardian } from "./guardians/RegistryGuardian.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "./libraries/AssetValuationLib.sol";
import { RegistryErrors } from "./libraries/Errors.sol";

/**
 * @title Registry
 * @author Pragma Labs
 * @notice The Registry has a number of responsibilities, all related to the management of Assets and Oracles:
 *  - It stores the mapping between assets and their respective Asset Modules.
 *  - It stores the mapping between oracles and their respective Oracle Modules.
 *  - It orchestrates the pricing of a basket of assets in a single unit of account.
 *  - It orchestrates deposits and withdrawals of an Account per Creditor.
 *  - It manages the risk parameters of all assets per Creditor.
 */
contract Registry is IRegistry, RegistryGuardian {
    using AssetValuationLib for AssetValueAndRiskFactors[];
    using BitPackingLib for bytes32;
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                               CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Arcadia Accounts Factory.
    address public immutable FACTORY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Counter with the number of oracles in the Registry.
    uint256 internal oracleCounter;

    // The contract address of the sequencer uptime oracle.
    address internal sequencerUptimeOracle;

    // Map registry => flag.
    mapping(address => bool) public inRegistry;
    // Map assetModule => flag.
    mapping(address => bool) public isAssetModule;
    // Map oracleModule => flag.
    mapping(address => bool) public isOracleModule;
    // Map asset => Asset Module.
    mapping(address => address) public assetToAssetModule;
    // Map oracle identifier => oracleModule.
    mapping(uint256 => address) internal oracleToOracleModule;
    // Map with the risk parameters for each Creditor.
    mapping(address creditor => RiskParameters) public riskParams;

    // Struct with the risk parameters for a specific Creditor.
    struct RiskParameters {
        // The minimum USD-value of assets that are taken into account, 18 decimals precision.
        uint128 minUsdValue;
        // The grace period after the sequencer is back up,
        // during which no transactions relying on pricing logic can be executed
        // (increasing open positions, withdrawing collateral and liquidations).
        uint64 gracePeriod;
        // The maximum number of recursive calls while processing an asset.
        uint64 maxRecursiveCalls;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AssetAdded(address indexed assetAddress, address indexed assetModule);
    event AssetModuleAdded(address assetModule);
    event Deposit(address account);
    event OracleAdded(uint256 indexed oracleId, address indexed oracleModule);
    event OracleModuleAdded(address oracleModule);
    event Withdrawal(address account);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only Accounts can call functions with this modifier.
     */
    modifier onlyAccount() {
        if (!IFactory(FACTORY).isAccount(msg.sender)) revert RegistryErrors.OnlyAccount();
        _;
    }

    /**
     * @dev Only Asset Modules can call functions with this modifier.
     */
    modifier onlyAssetModule() {
        if (!isAssetModule[msg.sender]) revert RegistryErrors.OnlyAssetModule();
        _;
    }

    /**
     * @dev Only Oracle Modules can call functions with this modifier.
     */
    modifier onlyOracleModule() {
        if (!isOracleModule[msg.sender]) revert RegistryErrors.OnlyOracleModule();
        _;
    }

    /**
     * @param creditor The contract address of the Creditor.
     * @dev Only the Risk Manager of a Creditor can call functions with this modifier.
     */
    modifier onlyRiskManager(address creditor) {
        if (msg.sender != ICreditor(creditor).riskManager()) revert RegistryErrors.Unauthorized();
        _;
    }

    /**
     * @param creditor The contract address of the Creditor.
     * @dev Throws if the sequencer is down,
     * or the Creditor specific grace period after sequencer is back up did not pass.
     */
    modifier sequencerNotDown(address creditor) {
        (, bool sequencerDown) = _isSequencerDown(creditor);
        if (sequencerDown) revert RegistryErrors.SequencerDown();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param factory The contract address of the Arcadia Accounts Factory.
     * @param sequencerUptimeOracle_ The contract address of the sequencer uptime oracle.
     */
    constructor(address factory, address sequencerUptimeOracle_) {
        FACTORY = factory;
        sequencerUptimeOracle = sequencerUptimeOracle_;

        // Check that the sequencer uptime oracle is not reverting.
        (bool success,) = _isSequencerDown(address(0));
        if (!success) revert RegistryErrors.OracleReverting();
    }

    /* ///////////////////////////////////////////////////////////////
                             L2 LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks that the sequencer is not down, and that it is back up for longer than the grace period.
     * @param creditor The contract address of the Creditor.
     * @return success Boolean indicating whether the sequencer uptime oracle not reverting.
     * @return sequencerDown Boolean indicating whether the sequencer is down, or is still within the grace period.
     * @dev This check guarantees that no stale oracles are consumed when the sequencer is down,
     * and that Account owners have time (the grace period) to bring their Account back in a healthy state.
     * @dev If the sequencer uptime oracle itself is reverting, the sequencer is assumed to be still up.
     */
    function _isSequencerDown(address creditor) internal view returns (bool success, bool sequencerDown) {
        // This guarantees that no stale oracles are consumed when the sequencer is down,
        // and that Account owners have time (the grace period) to bring their Account back in a healthy state.
        try IChainLinkData(sequencerUptimeOracle).latestRoundData() returns (
            uint80, int256 answer, uint256 startedAt, uint256, uint80
        ) {
            success = true;
            if (answer == 1 || block.timestamp - startedAt < riskParams[creditor].gracePeriod) {
                sequencerDown = true;
            }
        } catch { }
    }

    /**
     * @notice Sets a new sequencer uptime oracle in the case the current oracle is reverting.
     * @param sequencerUptimeOracle_ The contract address of the new sequencer uptime oracle.
     */
    function setSequencerUptimeOracle(address sequencerUptimeOracle_) external onlyOwner {
        // Check that the current sequencer uptime oracle is reverting.
        (bool success,) = _isSequencerDown(address(0));
        if (success) revert RegistryErrors.OracleNotReverting();

        // Set the new sequencer uptime oracle.
        sequencerUptimeOracle = sequencerUptimeOracle_;

        // Check that the new sequencer uptime oracle is not reverting.
        (success,) = _isSequencerDown(address(0));
        if (!success) revert RegistryErrors.OracleReverting();
    }

    /* ///////////////////////////////////////////////////////////////
                        MODULE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new Asset Module to the Registry.
     * @param assetModule The contract address of the Asset Module.
     */
    function addAssetModule(address assetModule) external onlyOwner {
        if (isAssetModule[assetModule]) revert RegistryErrors.AssetModNotUnique();
        isAssetModule[assetModule] = true;

        emit AssetModuleAdded(assetModule);
    }

    /**
     * @notice Adds a new Oracle Module to the Registry.
     * @param oracleModule The contract address of the Oracle Module.
     */
    function addOracleModule(address oracleModule) external onlyOwner {
        if (isOracleModule[oracleModule]) revert RegistryErrors.OracleModNotUnique();
        isOracleModule[oracleModule] = true;

        emit OracleModuleAdded(oracleModule);
    }

    /* ///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks if an asset is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) external view returns (bool) {
        address assetModule = assetToAssetModule[asset];

        // For unknown assets, assetModule will equal the zero-address.
        if (assetModule == address(0)) return false;

        return IAssetModule(assetModule).isAllowed(asset, assetId);
    }

    /**
     * @notice Adds a new asset to the Registry.
     * @param assetAddress The contract address of the asset.
     * @dev Assets that are already in the registry cannot be overwritten,
     * as that would make it possible for devs to change the asset pricing.
     */
    function addAsset(address assetAddress) external onlyAssetModule {
        if (inRegistry[assetAddress]) revert RegistryErrors.AssetAlreadyInRegistry();

        inRegistry[assetAddress] = true;

        emit AssetAdded(assetAddress, assetToAssetModule[assetAddress] = msg.sender);
    }

    /* ///////////////////////////////////////////////////////////////
                        ORACLE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new oracle to the Registry.
     * @return oracleId Unique identifier of the oracle.
     */
    function addOracle() external onlyOracleModule returns (uint256 oracleId) {
        // Get next id.
        oracleId = oracleCounter;

        unchecked {
            ++oracleCounter;
        }

        emit OracleAdded(oracleId, oracleToOracleModule[oracleId] = msg.sender);
    }

    /**
     * @notice Verifies whether a sequence of oracles complies with a predetermined set of criteria.
     * @param oracleSequence The sequence of the oracles to price a certain asset in USD,
     * packed in a single bytes32 object.
     * @return A boolean, indicating if the sequence complies with the set of criteria.
     * @dev The following checks are performed:
     * - The oracle must be previously added to the Registry and must still be active.
     * - The last Asset of oracles (except for the last oracle) must be equal to the first asset of the next oracle.
     * - The last Asset of the last oracle must be USD.
     */
    function checkOracleSequence(bytes32 oracleSequence) external view returns (bool) {
        (bool[] memory baseToQuoteAsset, uint256[] memory oracles) = oracleSequence.unpack();
        uint256 length = oracles.length;
        if (length == 0) revert RegistryErrors.Min1Oracle();
        // Length can be maximally 3, but no need to explicitly check it.
        // BitPackingLib.unpack() can maximally return arrays of length 3.

        address oracleModule;
        bytes16 baseAsset;
        bytes16 quoteAsset;
        bytes16 lastAsset;
        for (uint256 i; i < length; ++i) {
            oracleModule = oracleToOracleModule[oracles[i]];

            if (!IOracleModule(oracleModule).isActive(oracles[i])) return false;
            (baseAsset, quoteAsset) = IOracleModule(oracleModule).assetPair(oracles[i]);

            if (i == 0) {
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
        }

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors per asset for a given Creditor.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @return collateralFactors Array of the collateral factors of the assets for the Creditor, 4 decimals precision.
     * @return liquidationFactors Array of the liquidation factors of the assets for the Creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address[] calldata assetAddresses, uint256[] calldata assetIds)
        external
        view
        returns (uint16[] memory collateralFactors, uint16[] memory liquidationFactors)
    {
        uint256 length = assetAddresses.length;
        collateralFactors = new uint16[](length);
        liquidationFactors = new uint16[](length);
        for (uint256 i; i < length; ++i) {
            (collateralFactors[i], liquidationFactors[i]) = IAssetModule(assetToAssetModule[assetAddresses[i]])
                .getRiskFactors(creditor, assetAddresses[i], assetIds[i]);
        }
    }

    /**
     * @notice Sets the risk parameters for a given Creditor.
     * @param creditor The contract address of the Creditor.
     * @param minUsdValue The minimum USD-value of assets that are taken into account for the Creditor,
     * denominated in USD with 18 decimals precision.
     * @param gracePeriod The grace period after the sequencer is back up,
     * during which no transactions relying on pricing logic can be executed
     * (increasing open positions, withdrawing collateral and liquidations).
     * @param maxRecursiveCalls The maximum number of calls to different asset modules that are required to process
     * the deposit/withdrawal/pricing of a single asset.
     * @dev A minimum USD-value will help to avoid remaining dust amounts in Accounts, which couldn't be liquidated.
     */
    function setRiskParameters(address creditor, uint128 minUsdValue, uint64 gracePeriod, uint64 maxRecursiveCalls)
        external
        onlyRiskManager(creditor)
    {
        riskParams[creditor] =
            RiskParameters({ minUsdValue: minUsdValue, gracePeriod: gracePeriod, maxRecursiveCalls: maxRecursiveCalls });
    }

    /**
     * @notice Sets the risk parameters for a Primary Asset for a given Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param maxExposure The maximum exposure of a Creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     * @dev Any Creditor can set risk parameters for any asset, does not have any influence on risk parameters
     * set by other Creditors.
     */
    function setRiskParametersOfPrimaryAsset(
        address creditor,
        address asset,
        uint256 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external onlyRiskManager(creditor) {
        IPrimaryAM(assetToAssetModule[asset]).setRiskParameters(
            creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
    }

    /**
     * @notice Sets the risk parameters for the protocol of the Derived Asset Module for a given Creditor.
     * @param creditor The contract address of the Creditor.
     * @param assetModule The contract address of the Derived Asset Module.
     * @param maxUsdExposureProtocol The maximum USD exposure of the protocol for each Creditor,
     * denominated in USD with 18 decimals precision.
     * @param riskFactor The risk factor of the asset for the Creditor, 4 decimals precision.
     */
    function setRiskParametersOfDerivedAM(
        address creditor,
        address assetModule,
        uint112 maxUsdExposureProtocol,
        uint16 riskFactor
    ) external onlyRiskManager(creditor) {
        IDerivedAM(assetModule).setRiskParameters(creditor, maxUsdExposureProtocol, riskFactor);
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Batch deposits multiple assets.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * ...
     * @dev If no Creditor is set, only check that the assets are allowed (= can be priced).
     * @dev If a Creditor is set, processDirectDeposit in the Asset Module checks and updates the exposure for each asset
     * and if applicable, its underlying asset(s).
     */
    function batchProcessDeposit(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external whenDepositNotPaused onlyAccount returns (uint256[] memory assetTypes) {
        uint256 addrLength = assetAddresses.length;
        if (addrLength != assetIds.length || addrLength != amounts.length) revert RegistryErrors.LengthMismatch();

        assetTypes = new uint256[](addrLength);
        address assetAddress;
        if (creditor == address(0)) {
            bool isAllowed_;
            for (uint256 i; i < addrLength; ++i) {
                assetAddress = assetAddresses[i];
                // For unknown assets, assetModule will equal the zero-address and call reverts.
                (isAllowed_, assetTypes[i]) =
                    IAssetModule(assetToAssetModule[assetAddress]).processAsset(assetAddress, assetIds[i]);
                if (!isAllowed_) revert RegistryErrors.AssetNotAllowed();
            }
        } else {
            uint256 recursiveCalls;
            uint256 maxRecursiveCalls = riskParams[creditor].maxRecursiveCalls;
            for (uint256 i; i < addrLength; ++i) {
                assetAddress = assetAddresses[i];
                // For unknown assets, assetModule will equal the zero-address and call reverts.
                (recursiveCalls, assetTypes[i]) = IAssetModule(assetToAssetModule[assetAddress]).processDirectDeposit(
                    creditor, assetAddress, assetIds[i], amounts[i]
                );
                if (recursiveCalls > maxRecursiveCalls) revert RegistryErrors.MaxRecursiveCallsReached();
            }
        }

        // Emit Deposit event for account for indexing purposes.
        emit Deposit(msg.sender);
    }

    /**
     * @notice Batch withdraws multiple assets.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param amounts Array with the amounts of the assets.
     * @return assetTypes Array with the types of the assets.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     * ...
     * @dev If a Creditor is set, processDirectWithdrawal in the Asset Module updates the exposure for each asset and underlying asset.
     */
    function batchProcessWithdrawal(
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata amounts
    ) external whenWithdrawNotPaused onlyAccount returns (uint256[] memory assetTypes) {
        uint256 addrLength = assetAddresses.length;
        if (addrLength != assetIds.length || addrLength != amounts.length) revert RegistryErrors.LengthMismatch();

        assetTypes = new uint256[](addrLength);
        address assetAddress;
        if (creditor == address(0)) {
            for (uint256 i; i < addrLength; ++i) {
                assetAddress = assetAddresses[i];
                // For unknown assets, assetModule will equal the zero-address and call reverts.
                // The function doesn't revert as this might block assets in Accounts.
                (, assetTypes[i]) =
                    IAssetModule(assetToAssetModule[assetAddress]).processAsset(assetAddress, assetIds[i]);
            }
        } else {
            for (uint256 i; i < addrLength; ++i) {
                assetAddress = assetAddresses[i];
                // For unknown assets, assetModule will equal the zero-address and call reverts.
                assetTypes[i] = IAssetModule(assetToAssetModule[assetAddress]).processDirectWithdrawal(
                    creditor, assetAddress, assetIds[i], amounts[i]
                );
            }
        }

        // Emit Withdrawal event for account for indexing purposes.
        emit Withdrawal(msg.sender);
    }

    /**
     * @notice This function is called by Asset Modules of non-primary assets
     * in order to update the exposure of an underlying asset after a deposit.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset id.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset
     * since the last interaction.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @return usdExposureAssetToUnderlyingAsset The USD-value of the exposure of the asset to its underlying asset,
     * 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterDeposit(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external onlyAssetModule returns (uint256 recursiveCalls, uint256 usdExposureAssetToUnderlyingAsset) {
        (recursiveCalls, usdExposureAssetToUnderlyingAsset) = IAssetModule(assetToAssetModule[underlyingAsset])
            .processIndirectDeposit(
            creditor,
            underlyingAsset,
            underlyingAssetId,
            exposureAssetToUnderlyingAsset,
            deltaExposureAssetToUnderlyingAsset
        );
    }

    /**
     * @notice This function is called by Asset Modules of non-primary assets
     * in order to update the exposure of an underlying asset after a withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset id.
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
        usdExposureAssetToUnderlyingAsset = IAssetModule(assetToAssetModule[underlyingAsset]).processIndirectWithdrawal(
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
     * @notice Returns the rate of a certain primary asset in USD.
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     * @return rate The USD rate of an asset, 18 decimals precision.
     * @dev The oracle rate expresses how much USD (18 decimals precision) is required
     * to buy 1 token of the asset.
     */
    function getRateInUsd(bytes32 oracleSequence) external view returns (uint256 rate) {
        (bool[] memory baseToQuoteAsset, uint256[] memory oracles) = oracleSequence.unpack();

        rate = 1e18;

        uint256 length = oracles.length;
        for (uint256 i; i < length; ++i) {
            // Each Oracle has a fixed base asset and quote asset.
            // The oracle-rate expresses how much tokens of the quote asset (18 decimals precision) are required
            // to buy 1 token of the BaseAsset.
            if (baseToQuoteAsset[i]) {
                // "Normal direction" (how much of the QuoteAsset is required to buy 1 token of the BaseAsset).
                // -> Multiply with the oracle-rate.
                rate = rate.mulDivDown(IOracleModule(oracleToOracleModule[oracles[i]]).getRate(oracles[i]), 1e18);
            } else {
                // "Inverse direction" (how much of the BaseAsset is required to buy 1 token of the QuoteAsset).
                // -> Divide by the oracle-rate.
                rate = rate.mulDivDown(1e18, IOracleModule(oracleToOracleModule[oracles[i]]).getRate(oracles[i]));
            }
        }
    }

    /**
     * @notice Calculates the USD values of underlying assets.
     * @param creditor The contract address of the Creditor.
     * @param assets Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The values of the assets, denominated in USD with 18 Decimals precision
     * and the corresponding risk factors for each asset for the given Creditor.
     * @dev The function getValuesInUsdRecursive should only be called by Derived Asset Modules for recursive pricing of assets
     * and should NOT be used by external contracts.
     * This function does not do sanity checks such as:
     *  - Check if the sequencer is down or is back up less than the grace period.
     *  - Check if the value of the asset exceeds a minimal value to prevent dust attacks.
     */
    function getValuesInUsdRecursive(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        uint256 length = assets.length;
        valuesAndRiskFactors = new AssetValueAndRiskFactors[](length);
        for (uint256 i; i < length; ++i) {
            (
                valuesAndRiskFactors[i].assetValue,
                valuesAndRiskFactors[i].collateralFactor,
                valuesAndRiskFactors[i].liquidationFactor
            ) = IAssetModule(assetToAssetModule[assets[i]]).getValue(creditor, assets[i], assetIds[i], assetAmounts[i]);
        }
    }

    /**
     * @notice Calculates the USD-values per asset.
     * @param creditor The contract address of the Creditor.
     * @param assets Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The values of the assets, denominated in USD with 18 Decimals precision
     * and the corresponding risk factors for each asset for the given Creditor.
     * @dev getValuesInUsd is a function for internal calculations and should NOT be used by external contracts.
     * The function has a visibility public since it is also called by Derived Asset Modules for recursive pricing of assets.
     * This function does not check if the sequencer is down or is back up less than the grace period.
     */
    function getValuesInUsd(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) public view sequencerNotDown(creditor) returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        uint256 length = assets.length;
        valuesAndRiskFactors = new AssetValueAndRiskFactors[](length);

        uint256 minUsdValue = riskParams[creditor].minUsdValue;
        for (uint256 i; i < length; ++i) {
            (
                valuesAndRiskFactors[i].assetValue,
                valuesAndRiskFactors[i].collateralFactor,
                valuesAndRiskFactors[i].liquidationFactor
            ) = IAssetModule(assetToAssetModule[assets[i]]).getValue(creditor, assets[i], assetIds[i], assetAmounts[i]);
            // If asset value is too low, set to zero.
            // This is done to prevent dust attacks which may make liquidations unprofitable.
            if (valuesAndRiskFactors[i].assetValue < minUsdValue) valuesAndRiskFactors[i].assetValue = 0;
        }
    }

    /**
     * @notice Calculates the values per asset, denominated in a given Numeraire.
     * @param numeraire The contract address of the Numeraire.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The array of values per assets, denominated in the Numeraire.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the Numeraire, since getValue()-call will revert for unknown assets.
     * @dev Only fungible tokens can be used as Numeraire.
     */
    function getValuesInNumeraire(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view sequencerNotDown(creditor) returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        valuesAndRiskFactors = getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        // Convert the USD-values to values in Numeraire if the Numeraire is different from USD (0-address).
        if (numeraire != address(0)) {
            // We use the USD price per 10^18 tokens instead of the price per token to guarantee sufficient precision.
            (uint256 rateNumeraireToUsd,,) =
                IAssetModule(assetToAssetModule[numeraire]).getValue(address(0), numeraire, 0, 1e18);

            uint256 length = assetAddresses.length;
            for (uint256 i; i < length; ++i) {
                // "valuesAndRiskFactors.assetValue" is the USD-value of the asset with 18 decimals precision.
                // "rateNumeraireToUsd" is the USD-value of 10 ** 18 tokens of Numeraire with 18 decimals precision.
                // To get the asset value denominated in the Numeraire, we have to multiply USD-value of "assetValue" with 10**18
                // and divide by "rateNumeraireToUsd".
                valuesAndRiskFactors[i].assetValue =
                    valuesAndRiskFactors[i].assetValue.mulDivDown(1e18, rateNumeraireToUsd);
            }
        }
    }

    /**
     * @notice Calculates the combined value of a combination of assets, denominated in a given Numeraire.
     * @param numeraire The contract address of the Numeraire.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return assetValue The combined value of the assets, denominated in the Numeraire.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the Numeraire, since getValue()-call will revert for unknown assets.
     * @dev Only fungible tokens can be used as Numeraire.
     */
    function getTotalValue(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view sequencerNotDown(creditor) returns (uint256 assetValue) {
        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        uint256 length = assetAddresses.length;
        for (uint256 i = 0; i < length; ++i) {
            assetValue += valuesAndRiskFactors[i].assetValue;
        }

        // Convert the USD-value to the value in Numeraire if the Numeraire is different from USD (0-address).
        if (numeraire != address(0)) assetValue = _convertValueInUsdToValueInNumeraire(numeraire, assetValue);
    }

    /**
     * @notice Calculates the collateral value of a combination of assets, denominated in a given Numeraire.
     * @param numeraire The contract address of the Numeraire.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return collateralValue The collateral value of the assets, denominated in the Numeraire.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the Numeraire, since getValue()-call will revert for unknown assets.
     * @dev Only fungible tokens can be used as Numeraire.
     * @dev The collateral value is equal to the spot value of the assets,
     * discounted by a haircut (the collateral factor).
     */
    function getCollateralValue(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view sequencerNotDown(creditor) returns (uint256 collateralValue) {
        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        // Calculate the "collateralValue" in USD with 18 decimals precision.
        collateralValue = valuesAndRiskFactors._calculateCollateralValue();

        // Convert the USD-value to the value in Numeraire if the Numeraire is different from USD (0-address).
        if (numeraire != address(0)) {
            collateralValue = _convertValueInUsdToValueInNumeraire(numeraire, collateralValue);
        }
    }

    /**
     * @notice Calculates the getLiquidationValue of a combination of assets, denominated in a given Numeraire.
     * @param numeraire The contract address of the Numeraire.
     * @param creditor The contract address of the Creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return liquidationValue The liquidation value of the assets, denominated in the Numeraire.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     * @dev No need to check the Numeraire, since getValue()-call will revert for unknown assets.
     * @dev Only fungible tokens can be used as Numeraire.
     * @dev The liquidation value is equal to the spot value of the assets,
     * discounted by a haircut (the liquidation factor).
     */
    function getLiquidationValue(
        address numeraire,
        address creditor,
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view sequencerNotDown(creditor) returns (uint256 liquidationValue) {
        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);

        // Calculate the "liquidationValue" in USD with 18 decimals precision.
        liquidationValue = valuesAndRiskFactors._calculateLiquidationValue();

        // Convert the USD-value to the value in Numeraire if the Numeraire is different from USD (0-address).
        if (numeraire != address(0)) {
            liquidationValue = _convertValueInUsdToValueInNumeraire(numeraire, liquidationValue);
        }
    }

    /**
     * @notice Converts a value denominated in USD to a value denominated in the Numeraire.
     * @param numeraire The contract address of the Numeraire.
     * @param valueInUsd The value in USD, with 18 decimals precision.
     * @return valueInNumeraire The value denominated in the Numeraire.
     */
    function _convertValueInUsdToValueInNumeraire(address numeraire, uint256 valueInUsd)
        internal
        view
        returns (uint256 valueInNumeraire)
    {
        // We use the USD price per 10^18 tokens instead of the price per token to guarantee sufficient precision.
        (uint256 rateNumeraireToUsd,,) =
            IAssetModule(assetToAssetModule[numeraire]).getValue(address(0), numeraire, 0, 1e18);

        // "valueInUsd" is the USD-value of the assets with 18 decimals precision.
        // "rateNumeraireToUsd" is the USD-value of 10 ** 18 tokens of Numeraire with 18 decimals precision.
        // To get the value of the asset denominated in the Numeraire, we have to multiply USD-value of "valueInUsd" with 10**18
        // and divide by "rateNumeraireToUsd".
        valueInNumeraire = valueInUsd.mulDivDown(1e18, rateNumeraireToUsd);
    }
}
