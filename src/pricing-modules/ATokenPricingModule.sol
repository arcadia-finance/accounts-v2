/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DerivedPricingModule } from "./AbstractDerivedPricingModule.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";
import { IAToken } from "./interfaces/IAToken.sol";
import { IStandardERC20PricingModule } from "./interfaces/IStandardERC20PricingModule.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { FixedPointMathLib } from "../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title Pricing Module for Aave Yield Bearing ERC20 tokens
 * @author Pragma Labs
 * @notice The ATokenPricingModule stores pricing logic and basic information for yield bearing Aave ERC20 tokens for which a direct price feed exists
 * @dev No end-user should directly interact with the ATokenPricingModule, only the Main-registry, Oracle-Hub or the contract owner
 */
contract ATokenPricingModule is DerivedPricingModule {
    using FixedPointMathLib for uint256;

    mapping(address => ATokenAssetInformation) public aTokenAssetToInformation;
    address public immutable erc20PricingModule;

    struct ATokenAssetInformation {
        uint64 assetUnit;
        address[] underlyingAssetOracles;
    }

    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    /**
     * @notice A Pricing Module must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry.
     * @param oracleHub_ The address of the Oracle-Hub.
     * @param assetType_ Identifier for the type of asset, necessary for the deposit and withdraw logic in the Accounts.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * @param erc20PricingModule_ The address of the Pricing Module for standard ERC20 tokens.
     */
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address erc20PricingModule_)
        DerivedPricingModule(mainRegistry_, oracleHub_, assetType_, msg.sender)
    {
        erc20PricingModule = erc20PricingModule_;
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is white-listed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is whitelisted.
     */
    function isAllowListed(address asset, uint256) public view override returns (bool) {
        // NOTE: To change based on discussion to enable or disable deposits for certain assets
        return inPricingModule[asset];
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function _getKeyFromAsset(address asset, uint256) internal pure override returns (bytes32 key) {
        assembly {
            key := asset
        }
    }

    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }

    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssets)
    {
        underlyingAssets = assetToUnderlyingAssets[assetKey];
    }

    /**
     * @notice Adds a new asset to the ATokenPricingModule.
     * @param asset The contract address of the asset
     * @param riskVars An array of Risk Variables for the asset
     * @dev Only the Collateral Factor, Liquidation Threshold and basecurrency are taken into account.
     * If no risk variables are provided, the asset is added with the risk variables set to zero, meaning it can't be used as collateral.
     * @dev RiskVarInput.asset can be zero as it is not taken into account.
     * @dev Risk variable are variables with 2 decimals precision
     * @dev The assets are added in the Main-Registry as well.
     * @dev Assets can't have more than 18 decimals.
     */
    function addAsset(address asset, RiskVarInput[] calldata riskVars) external onlyOwner {
        uint256 assetUnit = 10 ** IERC20(asset).decimals();
        address underlyingAsset = IAToken(asset).UNDERLYING_ASSET_ADDRESS();

        (uint64 underlyingAssetUnit, address[] memory underlyingAssetOracles) =
            IStandardERC20PricingModule(erc20PricingModule).getAssetInformation(underlyingAsset);
        require(assetUnit == underlyingAssetUnit, "PMAT_AA: Decimals don't match");
        //we can skip the oracle addresses check, already checked on underlying asset

        require(!inPricingModule[asset], "PMAT_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        aTokenAssetToInformation[asset].assetUnit = uint64(assetUnit); //Can unsafe cast to uint64, we previously checked it is smaller than 10e18
        aTokenAssetToInformation[asset].underlyingAssetOracles = underlyingAssetOracles;

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(underlyingAsset, 0);
        assetToUnderlyingAssets[_getKeyFromAsset(asset, 0)] = underlyingAssets_;

        _setRiskVariablesForAsset(asset, riskVars);

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset,in the decimal precision of the Asset.
     * param underlyingAssetKeys The assets to which we have to get the conversion rate.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     */
    function _getUnderlyingAssetsAmounts(bytes32, uint256 assetAmount, bytes32[] memory)
        internal
        pure
        override
        returns (uint256[] memory underlyingAssetsAmounts)
    {
        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = assetAmount;
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - asset: The contract address of the asset
     * - assetId: Since ERC20 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of tokens, ERC20 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return collateralFactor The Collateral Factor of the asset
     * @return liquidationFactor The Liquidation Factor of the asset
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in ATokenPricingModule is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        uint256 rateInUsd =
            IOraclesHub(oracleHub).getRateInUsd(aTokenAssetToInformation[getValueInput.asset].underlyingAssetOracles);

        valueInUsd =
            (getValueInput.assetAmount).mulDivDown(rateInUsd, aTokenAssetToInformation[getValueInput.asset].assetUnit);

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
