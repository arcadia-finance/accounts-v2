/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { IRegistry } from "../interfaces/IRegistry.sol";
import { PrimaryAM } from "../abstracts/AbstractPrimaryAM.sol";

/**
 * @title Asset Module for the native token of the chain
 * @author Pragma Labs
 * @notice The pricing logic and basic information for The native token of the chain.
 * @dev No end-user should directly interact with the NativeTokenAM, only the Registry
 * or the contract owner.
 */
contract NativeTokenAM is PrimaryAM {
    /* //////////////////////////////////////////////////////////////
                               CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The unit of the native asset, equal to 10^decimals.
    uint64 public immutable ASSET_UNIT;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error Max18Decimals();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The contract address of the Registry.
     * @param decimals The number of decimals of the native asset.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "4" for the native token.
     */
    constructor(address registry_, uint256 decimals) PrimaryAM(registry_, 4) {
        if (decimals > 18) revert Max18Decimals();
        ASSET_UNIT = uint64(10 ** decimals);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new alias that represents the native asset to the NativeTokenAM.
     * @param asset An alias that represents the native asset.
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     * @dev Different protocols can use different "aliases" for the native asset, Uniswap v4 uses for instance the 0-address.
     */
    function addAsset(address asset, bytes32 oracleSequence) external onlyOwner {
        // View function, reverts in Registry if sequence is not correct.
        if (!IRegistry(REGISTRY).checkOracleSequence(oracleSequence)) revert BadOracleSequence();
        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), asset);

        inAssetModule[asset] = true;

        assetToInformation[_getKeyFromAsset(asset, 0)] =
            AssetInformation({ assetUnit: ASSET_UNIT, oracleSequence: oracleSequence });
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     * @dev Since the Native Token doesn't have an id, the id should be set to 0.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        return inAssetModule[asset];
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * param assetId The id of the asset.
     * @return key The unique identifier.
     * @dev The assetId is hard-coded to 0, since the assets for this Asset Module are the Native Token.
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
     * @return assetId The id of the asset.
     * @dev The assetId is hard-coded to 0, since the assets for this Asset Module are the Native Token.
     */
    function _getAssetFromKey(bytes32 key) internal pure override returns (address asset, uint256) {
        assembly {
            asset := key
        }

        return (asset, 0);
    }
}
