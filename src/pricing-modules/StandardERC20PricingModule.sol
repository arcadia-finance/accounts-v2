/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IERC20 } from "../interfaces/IERC20.sol";
import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { PrimaryPricingModule } from "./AbstractPrimaryPricingModule.sol";

/**
 * @title Pricing Module for Standard ERC20 tokens.
 * @author Pragma Labs
 * @notice The pricing logic and basic information for ERC20 tokens for which a direct price feed exists.
 * @dev No end-user should directly interact with the StandardERC20PricingModule, only the Main-registry
 * or the contract owner.
 */
contract StandardERC20PricingModule is PrimaryPricingModule {
    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The contract address of the MainRegistry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC20 tokens is 0.
     */
    constructor(address mainRegistry_) PrimaryPricingModule(mainRegistry_, 0) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the StandardERC20PricingModule.
     * @param asset The contract address of the asset.
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     * @dev Assets can't have more than 18 decimals.
     */
    function addAsset(address asset, bytes32 oracleSequence) external onlyOwner {
        // View function, reverts in MainRegistry if sequence is not correct.
        require(IMainRegistry(MAIN_REGISTRY).checkOracleSequence(oracleSequence), "PM20_AA: Bad Sequence");
        // Will revert in MainRegistry if asset was already added.
        IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);

        inPricingModule[asset] = true;

        uint256 assetUnit = 10 ** IERC20(asset).decimals();
        require(assetUnit <= 1e18, "PM20_AA: Maximal 18 decimals");

        // Can safely cast to uint64, we previously checked it is smaller than 10e18.
        assetToInformation[_getKeyFromAsset(asset, 0)] =
            AssetInformation({ assetUnit: uint64(assetUnit), oracleSequence: oracleSequence });
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     * @dev Since ERC20s don't have an Id, the Id should be set to 0.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        return inPricingModule[asset];
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0, since the assets for this Pricing Modules are ERC20's.
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
     * @dev The assetId is hard-coded to 0, since the assets for this Pricing Modules are ERC20's.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }
}
