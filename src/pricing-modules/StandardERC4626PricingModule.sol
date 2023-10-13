/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DerivedPricingModule } from "./AbstractDerivedPricingModule.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
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

    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

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
    function isAllowed(address asset, uint256) public view override returns (bool) {
        address underlyingAsset = IERC4626(asset).asset();

        return IMainRegistry(mainRegistry).isAllowed(underlyingAsset, 0);
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
     * @notice Adds a new asset to the ERC4626 TokenPricingModule.
     * @param asset The contract address of the asset
     */
    function addAsset(address asset) external onlyOwner {
        address underlyingAsset = address(IERC4626(asset).asset());

        require(IMainRegistry(mainRegistry).isAllowed(underlyingAsset, 0), "PM4626_AA: Underlying Asset not allowed");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(underlyingAsset, 0);
        assetToUnderlyingAssets[_getKeyFromAsset(asset, 0)] = underlyingAssets_;

        // Will revert in MainRegistry if pool was already added.
        IMainRegistry(mainRegistry).addAsset(asset, assetType);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset,in the decimal precision of the Asset.
     * param underlyingAssetKeys The assets to which we have to get the conversion rate.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     */
    function _getUnderlyingAssetsAmounts(bytes32 assetKey, uint256 assetAmount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts)
    {
        (address asset,) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = IERC4626(asset).convertToAssets(assetAmount);
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
        bytes32 assetKey = _getKeyFromAsset(getValueInput.asset, 0);

        bytes32[] memory underlyingAssetKeys = assetToUnderlyingAssets[assetKey];

        uint256[] memory underlyingAssetsAmounts =
            _getUnderlyingAssetsAmounts(assetKey, getValueInput.assetAmount, underlyingAssetKeys);

        (address asset,) = _getAssetFromKey(underlyingAssetKeys[0]);
        valueInUsd = IMainRegistry(mainRegistry).getUsdValue(
            GetValueInput({ asset: asset, assetId: 0, assetAmount: underlyingAssetsAmounts[0], baseCurrency: 0 })
        );

        collateralFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].collateralFactor;
        liquidationFactor = assetRiskVars[getValueInput.asset][getValueInput.baseCurrency].liquidationFactor;
    }
}
