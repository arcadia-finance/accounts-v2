/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { IMainRegistry } from "./interfaces/IMainRegistry.sol";
import { PrimaryAssetModule } from "./AbstractPrimaryAssetModule.sol";

/**
 * @title Asset Module for ERC1155 tokens
 * @author Pragma Labs
 * @notice The FloorERC1155AssetModule stores pricing logic and basic information for ERC1155 tokens,
 *  for which a direct price feed exists per Id.
 * @dev No end-user should directly interact with the FloorERC1155AssetModule, only the Main-registry or the contract owner
 */
contract FloorERC1155AssetModule is PrimaryAssetModule {
    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param mainRegistry_ The address of the Main-registry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC1155 tokens is 2.
     */
    constructor(address mainRegistry_) PrimaryAssetModule(mainRegistry_, 2) { }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to the FloorERC1155AssetModule.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @param oracleSequence The sequence of the oracles to price the asset in USD,
     * packed in a single bytes32 object.
     */
    function addAsset(address asset, uint256 assetId, bytes32 oracleSequence) external onlyOwner {
        if (inAssetModule[asset]) {
            // Contract address already added -> must be a new Id.
            require(
                assetToInformation[_getKeyFromAsset(asset, assetId)].assetUnit == 0, "AM1155_AA: Asset already in PM"
            );
        } else {
            // New contract address.
            IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);
            inAssetModule[asset] = true;
        }
        require(assetId <= type(uint96).max, "AM1155_AA: Invalid Id");
        require(IMainRegistry(MAIN_REGISTRY).checkOracleSequence(oracleSequence), "AM1155_AA: Bad Sequence");

        // Unit for ERC1155 is 1 (standard ERC1155s don't have decimals).
        assetToInformation[_getKeyFromAsset(asset, assetId)] =
            AssetInformation({ assetUnit: 1, oracleSequence: oracleSequence });
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset passed as input is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (assetToInformation[_getKeyFromAsset(asset, assetId)].assetUnit == 1) return true;

        return false;
    }

    /*///////////////////////////////////////////////////////////////
                    WITHDRAWALS AND DEPOSITS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Increases the exposure to an asset on a direct deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param amount The amount of tokens.
     */
    function processDirectDeposit(address creditor, address asset, uint256 assetId, uint256 amount)
        public
        override
        onlyMainReg
    {
        require(isAllowed(asset, assetId), "AM1155_PDD: Asset not allowed");

        super.processDirectDeposit(creditor, asset, assetId, amount);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Asset Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Asset Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Asset Module.
     * @return usdExposureUpperAssetToAsset The Usd value of the exposure of the upper asset to the asset of this Asset Module, 18 decimals precision.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyMainReg returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        require(isAllowed(asset, assetId), "AM1155_PID: Asset not allowed");

        (primaryFlag, usdExposureUpperAssetToAsset) = super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }
}
