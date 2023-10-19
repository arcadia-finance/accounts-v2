/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { IPricingModule } from "../interfaces/IPricingModule.sol";
import { PricingModule } from "./AbstractPricingModule.sol";

/**
 * @title Primary Pricing Module.
 * @author Pragma Labs
 */
abstract contract PrimaryPricingModule is PricingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Identifier indicating that it is a Primary Pricing Module:
    // the assets being priced have no underlying assets.
    bool internal constant PRIMARY_FLAG = true;
    // The contract address of the OracleHub.
    address public immutable ORACLE_HUB;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map with the last exposures of each asset.
    mapping(bytes32 assetKey => Exposure exposure) public exposure;

    // Struct with information about the exposure of a specific asset.
    struct Exposure {
        uint128 maxExposure; // The maximum exposure to an asset.
        uint128 exposureLast; // The exposure to an asset at its last interaction.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event MaxExposureSet(address indexed asset, uint128 maxExposure);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry.
     * @param oracleHub_ The address of the Oracle-Hub.
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the Accounts.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        PricingModule(mainRegistry_, assetType_, msg.sender)
    {
        ORACLE_HUB = oracleHub_;
    }

    /*///////////////////////////////////////////////////////////////
                    RISK VARIABLES MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum exposure for an asset.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param maxExposure The maximum protocol wide exposure to the asset.
     * @dev Can only be called by the Risk Manager, which can be different from the owner.
     */
    function setMaxExposureOfAsset(address asset, uint256 assetId, uint256 maxExposure)
        public
        virtual
        onlyRiskManager
    {
        require(maxExposure <= type(uint128).max, "APPM_SEA: Max Exp. not in limits");
        exposure[_getKeyFromAsset(asset, assetId)].maxExposure = uint128(maxExposure);

        emit MaxExposureSet(asset, uint128(maxExposure));
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
    function processDirectDeposit(address asset, uint256 assetId, uint256 amount) public virtual override onlyMainReg {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = exposure[assetKey].exposureLast;

        require(exposureLast + amount <= exposure[assetKey].maxExposure, "APPM_PDD: Exposure not in limits");

        unchecked {
            exposure[assetKey].exposureLast = uint128(exposureLast) + uint128(amount);
        }

        emit AssetExposureChanged(asset, uint128(exposureLast), exposure[assetKey].exposureLast);
    }

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectDeposit(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = exposure[assetKey].exposureLast;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= exposure[assetKey].maxExposure, "APPM_PID: Exposure not in limits");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        exposure[assetKey].exposureLast = uint128(exposureAsset);

        emit AssetExposureChanged(asset, uint128(exposureLast), uint128(exposureAsset));

        // Get Value in Usd
        (usdValueExposureUpperAssetToAsset,,) = getValue(
            IPricingModule.GetValueInput({
                asset: asset,
                assetId: assetId,
                assetAmount: exposureUpperAssetToAsset,
                baseCurrency: 0
            })
        );

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @dev Unsafe cast to uint128, it is assumed no more than 10**(20+decimals) tokens will ever be deposited.
     */
    function processDirectWithdrawal(address asset, uint256 assetId, uint256 amount)
        public
        virtual
        override
        onlyMainReg
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = exposure[assetKey].exposureLast;

        exposureLast >= amount
            ? exposure[assetKey].exposureLast = uint128(exposureLast) - uint128(amount)
            : exposure[assetKey].exposureLast = 0;

        emit AssetExposureChanged(asset, uint128(exposureLast), exposure[assetKey].exposureLast);
    }

    /**
     * @notice Decreases the exposure to an underlying asset on withdrawal.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectWithdrawal(
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);

        // Cache exposureLast.
        uint256 exposureLast = exposure[assetKey].exposureLast;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= type(uint128).max, "APPM_PIW: Overflow");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        exposure[assetKey].exposureLast = uint128(exposureAsset);

        emit AssetExposureChanged(asset, uint128(exposureLast), uint128(exposureAsset));

        // Get Value in Usd
        (usdValueExposureUpperAssetToAsset,,) = getValue(
            IPricingModule.GetValueInput({
                asset: asset,
                assetId: assetId,
                assetAmount: exposureUpperAssetToAsset,
                baseCurrency: 0
            })
        );

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }
}
