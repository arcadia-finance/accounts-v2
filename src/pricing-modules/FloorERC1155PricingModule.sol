/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";
import { PrimaryPricingModule } from "./AbstractPrimaryPricingModule.sol";

/**
 * @title Pricing Module for ERC1155 tokens
 * @author Pragma Labs
 * @notice The FloorERC1155PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC1155PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC1155PricingModule is PrimaryPricingModule {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToInformation;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        uint256 id;
        address[] oracles;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub.
     * @param mainRegistry_ The address of the Main-registry.
     * @param oracleHub_ The address of the Oracle-Hub.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC1155 tokens is 2.
     */
    constructor(address mainRegistry_, address oracleHub_) PrimaryPricingModule(mainRegistry_, oracleHub_, 2) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC1155PricingModule.
     * @param asset The contract address of the asset
     * @param assetId: The id of the collection
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables for the asset
     * @param maxExposure The maximum exposure of the asset in its own decimals
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     */
    function addAsset(
        address asset,
        uint256 assetId,
        address[] calldata oracles,
        RiskVarInput[] calldata riskVars,
        uint128 maxExposure
    ) external onlyOwner {
        // View function, reverts in OracleHub if sequence is not correct
        IOraclesHub(ORACLE_HUB).checkOracleSequence(oracles, asset);

        inPricingModule[asset] = true;

        require(assetId <= type(uint96).max, "PM1155_AA: Invalid Id");
        assetToInformation[asset].id = assetId;
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        exposure[_getKeyFromAsset(asset, assetId)].maxExposure = uint128(maxExposure);

        /// Will revert in MainRegistry if asset was already added.
        IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the information that is stored in the Pricing Module for a given asset
     * @param asset The Token address of the asset
     * @return id The id of the token
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint256, address[] memory) {
        return (assetToInformation[asset].id, assetToInformation[asset].oracles);
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is allowed
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (inPricingModule[asset]) {
            if (assetId == assetToInformation[asset].id) {
                return true;
            }
        }

        return false;
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
    function processDirectDeposit(address asset, uint256 assetId, uint256 amount) public override onlyMainReg {
        require(assetId == assetToInformation[asset].id, "PM1155_PDD: ID not allowed");

        super.processDirectDeposit(asset, assetId, amount);
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
    ) public override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        require(assetId == assetToInformation[asset].id, "PM1155_PID: ID not allowed");

        (primaryFlag, usdValueExposureUpperAssetToAsset) =
            super.processIndirectDeposit(asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
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
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256.
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in FloorERC1155PricingModule is necessary, since the check if the asset is added to the PricingModule
     * is already done in the MainRegistry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        uint256 rateInUsd = IOraclesHub(ORACLE_HUB).getRateInUsd(assetToInformation[getValueInput.asset].oracles);

        valueInUsd = getValueInput.assetAmount * rateInUsd;

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
