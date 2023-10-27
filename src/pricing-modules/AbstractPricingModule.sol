/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IPricingModule } from "../interfaces/IPricingModule.sol";
import { Owned } from "../../lib/solmate/src/auth/Owned.sol";
import { RiskConstants } from "../libraries/RiskConstants.sol";

/**
 * @title Abstract Pricing Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a Pricing Module.
 */
abstract contract PricingModule is Owned, IPricingModule {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier for the token standard of the asset.
    uint256 public immutable ASSET_TYPE;
    // The contract address of the MainRegistry.
    address public immutable MAIN_REGISTRY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The address of the riskManager.
    address public riskManager;

    // Map asset => flag.
    mapping(address => bool) public inPricingModule;
    // Map asset => baseCurrencyIdentifier => riskVariables.
    mapping(address => mapping(uint256 => RiskVars)) public assetRiskVars;

    // Struct with the risk variables of a specific asset for a specific baseCurrency.
    struct RiskVars {
        uint16 collateralFactor; // The collateral factor, 2 decimals precision.
        uint16 liquidationFactor; // The liquidation factor, 2 decimals precision.
    }

    // Struct with the input variables for the function setBatchRiskVariables().
    struct RiskVarInput {
        address asset; // The contract address of an asset.
        uint8 baseCurrency; // An identifier (uint256) of a BaseCurrency.
        uint16 collateralFactor; // The collateral factor, 2 decimals precision.
        uint16 liquidationFactor; // The liquidation factor, 2 decimals precision.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RiskManagerUpdated(address riskManager);
    event RiskVariablesSet(
        address indexed asset, uint8 indexed baseCurrencyId, uint16 collateralFactor, uint16 liquidationFactor
    );
    event AssetExposureChanged(address asset, uint128 oldExposure, uint128 newExposure);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only the Risk Manager can call functions with this modifier.
     */
    modifier onlyRiskManager() {
        require(msg.sender == riskManager, "APM: ONLY_RISK_MANAGER");
        _;
    }

    /**
     * @dev Only the Main Registry can call functions with this modifier.
     */
    modifier onlyMainReg() {
        require(msg.sender == MAIN_REGISTRY, "APM: ONLY_MAIN_REGISTRY");
        _;
    }

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
    constructor(address mainRegistry_, uint256 assetType_, address riskManager_) Owned(msg.sender) {
        MAIN_REGISTRY = mainRegistry_;
        ASSET_TYPE = assetType_;
        riskManager = riskManager_;

        emit RiskManagerUpdated(riskManager_);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     * @dev For assets without Id (ERC20, ERC4626...), the Id should be set to 0.
     */
    function isAllowed(address asset, uint256 assetId) public view virtual returns (bool);

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev Unsafe cast from uint256 to uint96, use only when the id's of the assets cannot exceed type(uint96).max.
     */
    function _getKeyFromAsset(address asset, uint256 assetId) internal view virtual returns (bytes32 key) {
        assembly {
            // Shift the assetId to the left by 20 bytes (160 bits).
            // This will remove the padding on the right.
            // Then OR the result with the address.
            key := or(shl(160, assetId), asset)
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The Id of the asset.
     */
    function _getAssetFromKey(bytes32 key) internal view virtual returns (address asset, uint256 assetId) {
        assembly {
            // Shift to the right by 20 bytes (160 bits) to extract the uint96 assetId.
            assetId := shr(160, key)

            // Use bitmask to extract the address from the rightmost 160 bits.
            asset := and(key, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }
    }

    /*///////////////////////////////////////////////////////////////
                    RISK MANAGER MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a new Risk Manager.
     * @param riskManager_ The address of the new Risk Manager.
     */
    function setRiskManager(address riskManager_) external onlyOwner {
        riskManager = riskManager_;

        emit RiskManagerUpdated(riskManager_);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * param getValueInput A Struct with the input variables.
     * - asset: The contract address of the asset.
     * - assetId: The Id of the asset.
     * - assetAmount: The amount of assets.
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     */
    function getValue(GetValueInput memory) public view virtual returns (uint256, uint256, uint256);

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk variables of an asset.
     * @param asset The contract address of the asset.
     * @param baseCurrency An identifier (uint256) of the BaseCurrency.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, 2 decimals precision.
     */
    function getRiskVariables(address asset, uint256 baseCurrency) public view virtual returns (uint16, uint16) {
        return
            (assetRiskVars[asset][baseCurrency].collateralFactor, assetRiskVars[asset][baseCurrency].liquidationFactor);
    }

    /**
     * @notice Sets a batch of risk variables for a batch of assets.
     * @param riskVarInputs An array of RiskVarInput structs.
     * @dev Risk variables have 2 decimals precision.
     * @dev Can only be called by the Risk Manager, which can be different from the owner.
     */
    function setBatchRiskVariables(RiskVarInput[] memory riskVarInputs) public virtual onlyRiskManager {
        uint256 baseCurrencyCounter = IMainRegistry(MAIN_REGISTRY).baseCurrencyCounter();
        uint256 riskVarInputsLength = riskVarInputs.length;

        for (uint256 i; i < riskVarInputsLength;) {
            require(riskVarInputs[i].baseCurrency < baseCurrencyCounter, "APM_SBRV: BaseCur. not in limits");

            _setRiskVariables(
                riskVarInputs[i].asset,
                riskVarInputs[i].baseCurrency,
                RiskVars({
                    collateralFactor: riskVarInputs[i].collateralFactor,
                    liquidationFactor: riskVarInputs[i].liquidationFactor
                })
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets a batch of risk variables for a specific asset.
     * @param asset The contract address of the asset.
     * @param riskVarInputs An array of RiskVarInput structs.
     * @dev Risk variables have 2 decimals precision.
     * @dev The asset slot in the RiskVarInput struct is ignored for this function.
     */
    function _setRiskVariablesForAsset(address asset, RiskVarInput[] memory riskVarInputs) internal virtual {
        uint256 baseCurrencyCounter = IMainRegistry(MAIN_REGISTRY).baseCurrencyCounter();
        uint256 riskVarInputsLength = riskVarInputs.length;

        for (uint256 i; i < riskVarInputsLength;) {
            require(baseCurrencyCounter > riskVarInputs[i].baseCurrency, "APM_SRVFA: BaseCur not in limits");
            _setRiskVariables(
                asset,
                riskVarInputs[i].baseCurrency,
                RiskVars({
                    collateralFactor: riskVarInputs[i].collateralFactor,
                    liquidationFactor: riskVarInputs[i].liquidationFactor
                })
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Sets a single pair of risk variables.
     * @param asset The contract address of the asset.
     * @param baseCurrency An identifier (uint256) of the BaseCurrency.
     * @param riskVars A struct with the risk variables.
     * @dev Risk variables have 2 decimals precision.
     */
    function _setRiskVariables(address asset, uint256 baseCurrency, RiskVars memory riskVars) internal virtual {
        require(riskVars.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR, "APM_SRV: Coll.Fact not in limits");
        require(riskVars.liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR, "APM_SRV: Liq.Fact not in limits");

        assetRiskVars[asset][baseCurrency] = riskVars;

        emit RiskVariablesSet(asset, uint8(baseCurrency), riskVars.collateralFactor, riskVars.liquidationFactor);
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
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount) public virtual;

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
    ) public virtual returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset);

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount) public virtual;

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
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
    ) public virtual returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset);
}
