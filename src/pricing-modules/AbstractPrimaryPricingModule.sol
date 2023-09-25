/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IMainRegistry } from "./interfaces/IMainRegistry_New.sol";
import { IPricingModule } from "../interfaces/IPricingModule_New.sol";
import { RiskConstants } from "../libraries/RiskConstants.sol";
import { Owned } from "../../lib/solmate/src/auth/Owned.sol";
import { PricingModule } from "./AbstractPricingModule_New.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title Primary Pricing Module.
 * @author Pragma Labs
 */
abstract contract PrimaryPricingModule is PricingModule {
    using FixedPointMathLib for uint256;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    bool internal constant PRIMARY_FLAG = true;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => exposureInformation.
    mapping(address => Exposure) public exposure;

    // Struct with information about the exposure of a specific asset.
    struct Exposure {
        uint128 maxExposure; // The maximum protocol wide exposure to an asset.
        uint128 exposure; // The actual protocol wide exposure to an asset.
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
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address erc20PricingModule_)
        PricingModule(mainRegistry_, oracleHub_, assetType_, msg.sender)
    { }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is whitelisted.
     * @dev For assets without Id (ERC20, ERC4626...), the Id should be set to 0.
     */
    function isAllowListed(address asset, uint256) public view virtual override returns (bool) {
        return exposure[asset].maxExposure != 0;
    }

    /**
     * @notice Sets the maximum exposure for an asset.
     * @param asset The contract address of the asset.
     * @param maxExposure The maximum protocol wide exposure to the asset.
     * @dev Can only be called by the Risk Manager, which can be different from the owner.
     */
    function setExposureOfAsset(address asset, uint256 maxExposure) public virtual onlyRiskManager {
        require(maxExposure <= type(uint128).max, "APPM_SEA: Max Exp. not in limits");
        exposure[asset].maxExposure = uint128(maxExposure);

        emit MaxExposureSet(asset, uint128(maxExposure));
    }

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address asset, uint256, uint256 amount) external virtual override onlyMainReg {
        // Cache exposureLast.
        uint256 exposureLast = exposure[asset].exposure;

        require(exposureLast + uint128(amount) <= exposure[asset].maxExposure, "APPM_PDD: Exposure not in limits");

        exposure[asset].exposure = uint128(exposureLast) + uint128(amount);
        emit AssetExposureChanged(asset, uint128(exposureLast), exposure[asset].exposure);
    }

    /**
     * @notice Increases the exposure to an underlying asset on deposit.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectDeposit(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) external virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Cache exposureLast.
        uint256 exposureLast = exposure[asset].exposure;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= exposure[asset].maxExposure, "APPM_PID: Exposure not in limits");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        exposure[asset].exposure = uint128(exposureAsset);

        emit AssetExposureChanged(asset, uint128(exposureLast), uint128(exposureAsset));

        // Get Value in Usd
        (usdValueExposureUpperAssetToAsset,,) = getValue(
            IPricingModule.GetValueInput({
                asset: asset,
                assetId: 0,
                assetAmount: exposureUpperAssetToAsset,
                baseCurrency: 0
            })
        );

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }

    /**
     * @notice Decreases the exposure to an asset on withdrawal.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @param amount The amount of tokens.
     * @dev Unsafe cast to uint128, it is assumed no more than 10**(20+decimals) tokens will ever be deposited.
     */
    function processDirectWithdrawal(address asset, uint256, uint256 amount) external virtual override onlyMainReg {
        // Cache exposureLast.
        uint256 exposureLast = exposure[asset].exposure;

        exposureLast >= amount
            ? exposure[asset].exposure = uint128(exposureLast) - uint128(amount)
            : exposure[asset].exposure = 0;

        emit AssetExposureChanged(asset, uint128(exposureLast), exposure[asset].exposure);
    }

    /**
     * @notice Decreases the exposure to an underlying asset on withdrawal.
     * @param asset The contract address of the asset.
     * param id The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function processIndirectWithdrawal(
        address asset,
        uint256,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) external virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        // Cache exposureLast.
        uint256 exposureLast = exposure[asset].exposure;

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = exposureLast + uint256(deltaExposureUpperAssetToAsset);
            require(exposureAsset <= type(uint128).max, "APPM_PIW: Overflow");
        } else {
            exposureAsset = exposureLast > uint256(-deltaExposureUpperAssetToAsset)
                ? exposureLast - uint256(-deltaExposureUpperAssetToAsset)
                : 0;
        }
        exposure[asset].exposure = uint128(exposureAsset);

        emit AssetExposureChanged(asset, uint128(exposureLast), uint128(exposureAsset));

        // Get Value in Usd
        (usdValueExposureUpperAssetToAsset,,) = getValue(
            IPricingModule.GetValueInput({
                asset: asset,
                assetId: 0,
                assetAmount: exposureUpperAssetToAsset,
                baseCurrency: 0
            })
        );

        return (PRIMARY_FLAG, usdValueExposureUpperAssetToAsset);
    }
}
