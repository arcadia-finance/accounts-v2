/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";
import { PrimaryPricingModule } from "./AbstractPrimaryPricingModule.sol";

/**
 * @title Pricing Module for ERC721 tokens for which a oracle exists for the floor price of the collection
 * @author Pragma Labs
 * @notice The FloorERC721PricingModule stores pricing logic and basic information for ERC721 tokens for which a direct price feeds exists
 * for the floor price of the collection
 * @dev No end-user should directly interact with the FloorERC721PricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract FloorERC721PricingModule is PrimaryPricingModule {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map asset => assetInformation.
    mapping(address => AssetInformation) public assetToInformation;

    // Struct with additional information for a specific asset.
    struct AssetInformation {
        uint256 idRangeStart;
        uint256 idRangeEnd;
        address[] oracles;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The address of the Main-registry.
     * @param oracleHub_ The address of the Oracle-Hub.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC721 tokens is 1.
     */
    constructor(address mainRegistry_, address oracleHub_) PrimaryPricingModule(mainRegistry_, oracleHub_, 1) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC721PricingModule.
     * @param asset The contract address of the asset
     * @param idRangeStart: The id of the first NFT of the collection
     * @param idRangeEnd: The id of the last NFT of the collection
     * @param oracles An array of addresses of oracle contracts, to price the asset in USD
     * @param riskVars An array of Risk Variables for the asset
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     */
    function addAsset(
        address asset,
        uint256 idRangeStart,
        uint256 idRangeEnd,
        address[] calldata oracles,
        RiskVarInput[] calldata riskVars
    ) external onlyOwner {
        // View function, reverts in OracleHub if sequence is not correct.
        IOraclesHub(ORACLE_HUB).checkOracleSequence(oracles, asset);

        inPricingModule[asset] = true;

        assetToInformation[asset].idRangeStart = idRangeStart;
        assetToInformation[asset].idRangeEnd = idRangeEnd;
        assetToInformation[asset].oracles = oracles;
        _setRiskVariablesForAsset(asset, riskVars);

        // Will revert in MainRegistry if asset was already added.
        IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the information that is stored in the Pricing Module for a given asset
     * @dev struct is not taken into memory; saves 6613 gas
     * @param asset The Token address of the asset
     * @return idRangeStart The id of the first token of the collection
     * @return idRangeEnd The id of the last token of the collection
     * @return oracles The list of addresses of the oracles to get the exchange rate of the asset in USD
     */
    function getAssetInformation(address asset) external view returns (uint256, uint256, address[] memory) {
        return (
            assetToInformation[asset].idRangeStart,
            assetToInformation[asset].idRangeEnd,
            assetToInformation[asset].oracles
        );
    }

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (inPricingModule[asset]) {
            if (isIdInRange(asset, assetId)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice Checks if the Id for a given token is in the range for which there exists a price feed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the Id of the given asset is in range.
     */
    function isIdInRange(address asset, uint256 assetId) private view returns (bool) {
        if (assetId >= assetToInformation[asset].idRangeStart && assetId <= assetToInformation[asset].idRangeEnd) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0.
     * Since all assets of the same ERC721 collection are floor NFTs, we only care about total exposures per collection,
     * not of individual ids.
     */
    function _getKeyFromAsset(address asset, uint256) internal pure override returns (bytes32 key) {
        assembly {
            key := asset
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The Id of the asset.
     * @dev The assetId is hard-coded to 0.
     * Since all assets of the same ERC721 collection are floor NFTs, we only care about total exposures per collection,
     * not of individual ids.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on deposit.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * param amount The amount of tokens.
     * @dev amount of a deposit in ERC721 pricing module must be 1.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256)
        public
        override
        onlyMainReg
    {
        require(isIdInRange(asset, assetId), "PM721_PDD: ID not allowed");

        super.processDirectDeposit(creditor, asset, assetId, 1);
    }

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
    ) public virtual override onlyMainReg returns (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) {
        require(isIdInRange(asset, assetId), "PM721_PID: ID not allowed");

        return super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the usd value of an asset.
     * @param getValueInput A Struct with the input variables.
     * - asset: The contract address of the asset.
     * - assetId: The Id of the asset
     * - assetAmount: The amount of floor NFTs, a natural number without decimals (1 by default for ERC721).
     * - baseCurrency: The BaseCurrency in which the value is ideally denominated.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given baseCurrency, with 2 decimals precision.
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in FloorERC721PricingModule is necessary, since the check if the asset is added to the PricingModule
     * is already done in the MainRegistry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        valueInUsd = IOraclesHub(ORACLE_HUB).getRateInUsd(assetToInformation[getValueInput.asset].oracles)
            * getValueInput.assetAmount;

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
