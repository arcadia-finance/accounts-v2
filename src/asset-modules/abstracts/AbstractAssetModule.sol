/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IAssetModule } from "../../interfaces/IAssetModule.sol";
import { Owned } from "../../../lib/solmate/src/auth/Owned.sol";

/**
 * @title Abstract Asset Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of an Asset Module.
 * @dev Each different asset class should have its own Oracle Module.
 * The Asset Modules will:
 *  - Implement the pricing logic to calculate the USD value (with 18 decimals precision).
 *  - Process Deposits and Withdrawals.
 *  - Manage the risk parameters.
 */
abstract contract AssetModule is Owned, IAssetModule {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier for the token standard of the asset.
    uint256 public immutable ASSET_TYPE;
    // The contract address of the Registry.
    address public immutable REGISTRY;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => flag.
    mapping(address => bool) public inAssetModule;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error ExposureNotInLimits();
    error OnlyRegistry();
    error Overflow();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Only the Registry can call functions with this modifier.
     */
    modifier onlyRegistry() {
        if (msg.sender != REGISTRY) revert OnlyRegistry();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param assetType_ Identifier for the token standard of the asset.
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    constructor(address registry_, uint256 assetType_) Owned(msg.sender) {
        REGISTRY = registry_;
        ASSET_TYPE = assetType_;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     * @dev For assets without id (ERC20, ERC4626...), the id should be set to 0.
     */
    function isAllowed(address asset, uint256 assetId) public view virtual returns (bool);

    /**
     * @notice Returns if an asset is allowed and its asset type.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     * @return assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155
     * ...
     */
    function processAsset(address asset, uint256 assetId) external view virtual returns (bool, uint256) {
        return (isAllowed(asset, assetId), ASSET_TYPE);
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return key The unique identifier.
     * @dev Unsafe bitshift from uint256 to uint96, use only when the ids of the assets cannot exceed type(uint96).max.
     * For asset where the id can be bigger than a uint96, use a mapping of asset and assetId to storage.
     * These assets can however NOT be used as underlying assets (processIndirectDeposit() must revert).
     */
    function _getKeyFromAsset(address asset, uint256 assetId) internal view virtual returns (bytes32 key) {
        assembly {
            // Shift the assetId to the left by 20 bytes (160 bits).
            // Then OR the result with the address.
            key := or(shl(160, assetId), asset)
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The id of the asset.
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
        virtual
        returns (uint256, uint256, uint256);

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

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
        virtual
        returns (uint16 collateralFactor, uint16 liquidationFactor);

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
     * @return assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155
     * ...
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        returns (uint256 recursiveCalls, uint256 assetType);

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
    ) public virtual returns (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset);

    /**
     * @notice Decreases the exposure to an asset on a direct withdrawal.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param amount The amount of tokens.
     * @return assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155
     * ...
     */
    function processDirectWithdrawal(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        virtual
        returns (uint256 assetType);

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
    ) public virtual returns (uint256 usdExposureUpperAssetToAsset);
}
