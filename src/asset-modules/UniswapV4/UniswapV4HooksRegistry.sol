/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.30;

import { AssetModule, IAssetModule, Owned } from "../abstracts/AbstractAM.sol";
import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DefaultUniswapV4AM } from "./DefaultUniswapV4AM.sol";
import { Hooks } from "./libraries/Hooks.sol";
import { ICreditor } from "../../interfaces/ICreditor.sol";
import { IDerivedAM } from "../../interfaces/IDerivedAM.sol";
import { IPositionManager } from "./interfaces/IPositionManager.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";
import { PoolIdLibrary } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";
import { PoolKey } from "../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { RegistryErrors } from "../../libraries/Errors.sol";

/**
 * @title Registry for Uniswap V4 Hooks.
 * @author Pragma Labs
 * @notice The Uniswap V4 Hooks Registry stores the mapping between Uniswap V4 Hooks contracts and their respective Asset Modules.
 */
contract UniswapV4HooksRegistry is AssetModule {
    using PoolIdLibrary for PoolKey;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the PositionManager.
    IPositionManager internal immutable POSITION_MANAGER;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The contract address of the default Asset Module for Uniswap V4 hooks.
    address public immutable DEFAULT_UNISWAP_V4_AM;

    // Map registry => flag.
    mapping(address => bool) internal _inRegistry;
    // Map assetModule => flag.
    mapping(address => bool) public isAssetModule;
    // Map hooks => Specific Uniswap V4 Asset Module.
    mapping(address hooks => address assetModule) public hooksToAssetModule;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AssetModuleAdded(address assetModule);
    event HooksAdded(address indexed hooks, address indexed assetModule);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only Asset Modules can call functions with this modifier.
     */
    modifier onlyAssetModule() {
        if (!isAssetModule[msg.sender]) revert RegistryErrors.OnlyAssetModule();
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

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param positionManager The contract address of the uniswapV4 PositionManager.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for Uniswap V4 Liquidity Positions (ERC721).
     */
    constructor(address registry_, address positionManager) AssetModule(registry_, 2) {
        POSITION_MANAGER = IPositionManager(positionManager);

        // Deploy the Default Uniswap V4 AM.
        DEFAULT_UNISWAP_V4_AM = address(new DefaultUniswapV4AM(address(this), positionManager));
        DefaultUniswapV4AM(DEFAULT_UNISWAP_V4_AM).transferOwnership(msg.sender);
        isAssetModule[DEFAULT_UNISWAP_V4_AM] = true;

        emit AssetModuleAdded(DEFAULT_UNISWAP_V4_AM);
    }

    /* ///////////////////////////////////////////////////////////////
                        MODULE MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a new Asset Module to the Hooks Registry.
     * @param assetModule The contract address of the Asset Module.
     */
    function addAssetModule(address assetModule) external onlyOwner {
        if (isAssetModule[assetModule]) revert RegistryErrors.AssetModNotUnique();
        isAssetModule[assetModule] = true;

        emit AssetModuleAdded(assetModule);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds the mapping from the PositionManager to this intermediate Hooks Registry in the "Main" Registry.
     */
    function setProtocol() external onlyOwner {
        inAssetModule[address(POSITION_MANAGER)] = true;

        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), address(POSITION_MANAGER));
    }

    /**
     * @notice Adds a new hooks contract to the Hooks Registry.
     * @param assetType Identifier for the type of the asset.
     * @param hooks The contract address of the hooks.
     * @dev Hooks that are already in the registry cannot be overwritten,
     * as that would make it possible for devs to change the asset pricing.
     * @dev All hooks contracts that can be priced by the Default Uniswap V4 AM
     * (no hook implemented on before or after removing liquidity) are automatically added to the Hooks Registry.
     * Hence they cannot be added by specific Uniswap V4 AMs.
     */
    function addHooks(uint96 assetType, address hooks) external onlyAssetModule {
        if (assetType != 2) revert RegistryErrors.InvalidAssetType();
        if (inRegistry(hooks)) revert RegistryErrors.AssetAlreadyInRegistry();

        _inRegistry[hooks] = true;
        hooksToAssetModule[hooks] = msg.sender;

        emit HooksAdded(hooks, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        // If the caller is an Asset Module, check if the asset is allowed in the Registry.
        if (isAssetModule[msg.sender]) return IRegistry(REGISTRY).isAllowed(asset, assetId);

        // Else pass the call to its Asset Module.
        address assetModule = getAssetModule(assetId);
        if (assetModule == address(0)) return false;
        return IAssetModule(assetModule).isAllowed(asset, assetId);
    }

    /**
     * @notice Checks if a hooks contract is in the Hooks Registry.
     * @param hooks The contract address of the hooks.
     * @return bool indicating if the hook is in the Hooks Registry.
     */
    function inRegistry(address hooks) public view returns (bool) {
        // Specific Uniswap V4 AM can only be set if the default Uniswap V4 AM cannot be used.
        if (
            Hooks.hasPermission(uint160(hooks), Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG)
                || Hooks.hasPermission(uint160(hooks), Hooks.AFTER_REMOVE_LIQUIDITY_FLAG)
        ) {
            // Check if hook is added by a specific Uniswap V4 AM.
            return _inRegistry[hooks];
        } else {
            // Hooks that can be priced by the Default Uniswap V4 AM are automatically added to the Hooks Registry.
            return true;
        }
    }

    /**
     * @notice Returns the Asset Manager for a given position Id.
     * @param assetId The id of the asset.
     * @return assetModule The contract address of the Asset Module.
     */
    function getAssetModule(uint256 assetId) public view returns (address assetModule) {
        (PoolKey memory poolKey,) = POSITION_MANAGER.getPoolAndPositionInfo(assetId);

        // If the assetId does not exist, the poolKey will have zero-values,
        // and for an existing pool tickSpacing can't be zero.
        if (poolKey.tickSpacing == 0) return address(0);

        // Check if we can use the default Uniswap V4 AM.
        if (
            Hooks.hasPermission(uint160(address(poolKey.hooks)), Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG)
                || Hooks.hasPermission(uint160(address(poolKey.hooks)), Hooks.AFTER_REMOVE_LIQUIDITY_FLAG)
        ) {
            // If not a specific Uniswap V4 AM must have been set.
            // Returns the zero address if no Asset Module is set.
            assetModule = hooksToAssetModule[address(poolKey.hooks)];
        } else {
            // If BEFORE_REMOVE_LIQUIDITY_FLAG and AFTER_REMOVE_LIQUIDITY_FLAG are not set,
            // then we use the default Uniswap V4 AM.
            // The NoOP hook "AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG" is by default not allowed,
            // as it can only be accessed if "AFTER_REMOVE_LIQUIDITY_FLAG" is implemented.
            assetModule = DEFAULT_UNISWAP_V4_AM;
        }
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
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
        override
        returns (uint256, uint256, uint256)
    {
        return IAssetModule(getAssetModule(assetId)).getValue(creditor, asset, assetId, assetAmount);
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

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
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        return IAssetModule(getAssetModule(assetId)).getRiskFactors(creditor, asset, assetId);
    }

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
        (collateralFactors, liquidationFactors) = IRegistry(REGISTRY).getRiskFactors(creditor, assetAddresses, assetIds);
    }

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
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        onlyRegistry
        returns (uint256 recursiveCalls)
    {
        return IAssetModule(getAssetModule(assetId)).processDirectDeposit(creditor, asset, assetId, amount);
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
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyRegistry returns (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) {
        return IAssetModule(getAssetModule(assetId)).processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }

    /**
     * @notice Decreases the exposure to an asset on a direct withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        onlyRegistry
    {
        return IAssetModule(getAssetModule(assetId)).processDirectWithdrawal(creditor, asset, assetId, amount);
    }

    /**
     * @notice Decreases the exposure to an asset on an indirect withdrawal.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return usdExposureUpperAssetToAsset The USD value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyRegistry returns (uint256 usdExposureUpperAssetToAsset) {
        return IAssetModule(getAssetModule(assetId)).processIndirectWithdrawal(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
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
        return IRegistry(REGISTRY).getUsdValueExposureToUnderlyingAssetAfterDeposit(
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
        return IRegistry(REGISTRY).getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
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
     * @notice Calculates the USD values of underlying assets.
     * @param creditor The contract address of the Creditor.
     * @param assets Array of the contract addresses of the assets.
     * @param assetIds Array of the ids of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The values of the assets, denominated in USD with 18 Decimals precision
     */
    function getValuesInUsdRecursive(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors) {
        return IRegistry(REGISTRY).getValuesInUsdRecursive(creditor, assets, assetIds, assetAmounts);
    }
}
