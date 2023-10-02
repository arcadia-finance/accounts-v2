/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DerivedPricingModule } from "./AbstractDerivedPricingModule.sol";
import { IMainRegistry_New } from "./interfaces/IMainRegistry_New.sol";
import { IOraclesHub } from "./interfaces/IOraclesHub.sol";
import { IERC4626 } from "../interfaces/IERC4626.sol";
import { IStandardERC20PricingModule } from "./interfaces/IStandardERC20PricingModule.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @title Sub-registry for Standard ERC4626 tokens
 * @author Pragma Labs
 * @notice The StandardERC4626Registry stores pricing logic and basic information for ERC4626 tokens for which the underlying assets have direct price feed.
 * @dev No end-user should directly interact with the StandardERC4626Registry, only the Main-registry, Oracle-Hub or the contract owner
 */
contract StandardERC4626PricingModule is DerivedPricingModule {
    using FixedPointMathLib for uint256;

    mapping(address => ERC4626AssetInformation) public erc4626AssetToInformation;
    address public immutable erc20PricingModule;

    struct ERC4626AssetInformation {
        uint64 assetUnit;
        address[] underlyingAssetOracles;
    }

    /**
     * @notice A Sub-Registry must always be initialised with the address of the Main-Registry and of the Oracle-Hub
     * @param mainRegistry_ The address of the Main-registry
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
        uint256 assetUnit = 10 ** IERC4626(asset).decimals();
        address underlyingAsset = address(IERC4626(asset).asset());

        (uint64 underlyingAssetUnit, address[] memory underlyingAssetOracles) =
            IStandardERC20PricingModule(erc20PricingModule).getAssetInformation(underlyingAsset);
        require(10 ** IERC4626(asset).decimals() == underlyingAssetUnit, "PM4626_AA: Decimals don't match");
        //we can skip the oracle addresses check, already checked on underlying asset

        require(!inPricingModule[asset], "PM4626_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        erc4626AssetToInformation[asset].assetUnit = uint64(assetUnit);
        erc4626AssetToInformation[asset].underlyingAssetOracles = underlyingAssetOracles;

        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = underlyingAsset;
        uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);

        assetToInformation[asset].underlyingAssets = underlyingAssets;
        assetToInformation[asset].exposureAssetToUnderlyingAssetsLast = exposureAssetToUnderlyingAssetsLast;

        _setRiskVariablesForAsset(asset, riskVars);

        //Will revert in MainRegistry if asset can't be added
        IMainRegistry_New(mainRegistry).addAsset(asset, assetType);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the conversion rate of an asset to its underlying asset.
     * @param asset The asset to calculate the conversion rate for.
     * param assetId The id of the asset to calculate the conversion rate for.
     * param underlyingAssets The assets to which we have to get the conversion rate.
     * @return conversionRates The conversion rate of the asset to its underlying assets.
     */
    function _getConversionRates(address asset, uint256, address[] memory)
        internal
        view
        override
        returns (uint256[] memory conversionRates)
    {
        conversionRates = new uint256[](1);
        conversionRates[0] = IERC4626(asset).convertToAssets(1e18);
    }

    /**
     * @notice Returns the value of a certain asset, denominated in USD or in another BaseCurrency
     * @param getValueInput A Struct with all the information neccessary to get the value of an asset
     * - assetAddress: The contract address of the asset
     * - assetId: Since ERC4626 tokens have no Id, the Id should be set to 0
     * - assetAmount: The Amount of Shares, ERC4626 tokens can have any Decimals precision smaller than 18.
     * - baseCurrency: The BaseCurrency in which the value is ideally expressed
     * @return valueInUsd The value of the asset denominated in USD with 18 Decimals precision
     * @return collateralFactor The Collateral Factor of the asset
     * @return liquidationFactor The Liquidation Factor of the asset
     * @dev Function will overflow when assetAmount * Rate * 10**(18 - rateDecimals) > MAXUINT256
     * @dev If the asset is not first added to PricingModule this function will return value 0 without throwing an error.
     * However no check in StandardERC4626Registry is necessary, since the check if the asset is whitelisted (and hence added to PricingModule)
     * is already done in the Main-Registry.
     */
    function getValue(GetValueInput memory getValueInput)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        uint256 rateInUsd =
            IOraclesHub(oracleHub).getRateInUsd(erc4626AssetToInformation[getValueInput.asset].underlyingAssetOracles);

        uint256 assetAmount = IERC4626(getValueInput.asset).convertToAssets(getValueInput.assetAmount);

        valueInUsd = assetAmount.mulDivDown(rateInUsd, erc4626AssetToInformation[getValueInput.asset].assetUnit);

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
