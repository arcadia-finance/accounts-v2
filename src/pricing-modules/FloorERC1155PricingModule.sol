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
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
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
     * @param asset The contract address of the asset.
     * @param assetId: The id of the collection.
     * @param oracles The sequence of the oracles, to price the asset in USD.
     */
    function addAsset(address asset, uint256 assetId, bytes32 oracles) external onlyOwner {
        if (inPricingModule[asset]) {
            // Contract address already added -> must have a new Id.
            require(
                assetToInformation2[_getKeyFromAsset(asset, assetId)].assetUnit == 0, "PM1155_AA: Asset already in PM"
            );
        } else {
            // New contract address.
            IMainRegistry(MAIN_REGISTRY).addAsset(asset, ASSET_TYPE);
            inPricingModule[asset] = true;
        }
        require(assetId <= type(uint96).max, "PM1155_AA: Invalid Id");
        require(IMainRegistry(MAIN_REGISTRY).checkOracleSequence(oracles), "PM1155_AA: Bad Sequence");

        // Unit for ERC1155 is 1 (standard ERC1155s don't have decimals).
        assetToInformation2[_getKeyFromAsset(asset, assetId)] = AssetInformation2({ assetUnit: 1, oracles: oracles });
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed
     * @param asset The address of the asset
     * @param assetId The Id of the asset
     * @return A boolean, indicating if the asset passed as input is allowed
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool) {
        if (assetToInformation2[_getKeyFromAsset(asset, assetId)].assetUnit == 1) return true;

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
        require(isAllowed(asset, assetId), "PM1155_PDD: Asset not allowed");

        super.processDirectDeposit(creditor, asset, assetId, amount);
    }

    /**
     * @notice Increases the exposure to an asset on an indirect deposit.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param exposureUpperAssetToAsset The amount of exposure of the upper asset to the asset of this Pricing Module.
     * @param deltaExposureUpperAssetToAsset The increase or decrease in exposure of the upper asset to the asset of this Pricing Module since last interaction.
     * @return primaryFlag Identifier indicating if it is a Primary or Derived Pricing Module.
     * @return usdExposureUpperAssetToAsset The Usd value of the exposure of the upper asset to the asset of this Pricing Module, 18 decimals precision.
     */
    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override onlyMainReg returns (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) {
        require(isAllowed(asset, assetId), "PM1155_PID: Asset not allowed");

        (primaryFlag, usdExposureUpperAssetToAsset) = super.processIndirectDeposit(
            creditor, asset, assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
    }
}
