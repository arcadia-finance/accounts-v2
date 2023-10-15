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
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

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
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        address underlyingAsset = IERC4626(asset).asset();

        return IMainRegistry(mainRegistry).isAllowed(underlyingAsset, 0);
    }

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

        if (underlyingAssets.length == 0) {
            // Only used as an off-chain view function to return the value of a non deposited Liquidity Position.
            (address asset,) = _getAssetFromKey(assetKey);
            address underlyingAsset = address(IERC4626(asset).asset());

            underlyingAssets = new bytes32[](1);
            underlyingAssets[0] = _getKeyFromAsset(underlyingAsset, 0);
        }
    }

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
        returns (uint256[] memory underlyingAssetsAmounts, uint256[] memory rateUnderlyingAssetsToUsd)
    {
        (address asset,) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = IERC4626(asset).convertToAssets(assetAmount);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }
}
