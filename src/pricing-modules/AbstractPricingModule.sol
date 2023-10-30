/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IPricingModule } from "../interfaces/IPricingModule.sol";
import { Owned } from "../../lib/solmate/src/auth/Owned.sol";

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

    // Map asset => flag.
    mapping(address => bool) public inPricingModule;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

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
     */
    constructor(address mainRegistry_, uint256 assetType_) Owned(msg.sender) {
        MAIN_REGISTRY = mainRegistry_;
        ASSET_TYPE = assetType_;
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
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * param getValueInput A Struct with the input variables.
     * - asset: The contract address of the asset.
     * - assetId: The Id of the asset.
     * - assetAmount: The amount of assets.
     * - creditor: The contract address of the creditor.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     */
    function getValue(GetValueInput memory) public view virtual returns (uint256, uint256, uint256);

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
        returns (uint16 collateralFactor, uint16 liquidationFactor);

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
    ) public virtual returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset);

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
    ) public virtual returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset);
}
