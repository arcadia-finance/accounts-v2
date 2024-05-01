/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ActionData, IActionBase } from "../interfaces/IActionBase.sol";
import {
    CollectParams,
    IncreaseLiquidityParams,
    INonfungiblePositionManager
} from "../asset-modules/UniswapV3/interfaces/INonfungiblePositionManager.sol";
import { IAccount } from "../interfaces/IAccount.sol";
import { IPermit2 } from "../interfaces/IPermit2";

contract AutoCompounder is IActionBase {
    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InvalidERC721Amount();
    error InvalidAssetType();

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() { }

    /* ///////////////////////////////////////////////////////////////
                             COMPOUNDING LOGIC
    /////////////////////////////////////////////////////////////// */

    function compoundRewardsForAccount(address account, ActionData memory assetData) external {
        // Check condition from Beefy (on which size + fee should we decide to trigger this function ?)

        if (withdrawData.assetAmounts[0] != 1) revert InvalidERC721Amount();
        if (withdrawData.assetTypes[0] != 2) revert InvalidAssetType();
        if (
            withdrawData.assets.length + withdrawData.assetIds.length + withdrawData.assetAmounts.length
                + withdrawData.assetTypes.length != 4
        ) revert InvalidLength();

        // Empty data needed to encode in actionData
        bytes memory signature;
        ActionData memory transferFromOwner;
        IPermit2.PermitBatchTransferFrom memory permit;

        bytes memory compounderData = abi.encode(assetData);
        bytes memory actionData = abi.encode(assetData, transferFromOwner, permit, signature, compounderData);
        // Trigger flashAction with actionTarget as this contract
        -IAccount(account).flashAction(address(this), actionData);

        // executeAction() triggered as callback function
    }

    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param actionData A bytes object containing one actionData struct, an address array and a bytes array.
     * @return depositData The modified `ActionData` struct representing the final state of the `depositData` after executing the action.
     */
    function executeAction(bytes calldata actionData) external override returns (ActionData memory) {
        // NFT transferred from Account
        // Get NFT data
        ActionData memory assetData = abi.decode(actionData, (ActionData));

        // Claim fees for the NFT
        CollectParams memory collectParams = CollectParams({
            tokenId: assetData.assetIds[0],
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (uint256 feeAmount0, uint256 feeAmount1) =
            INonfungiblePositionManager(assetData.assets[0]).collect(collectParams);

        // Assume pool is balanced 50/50
        // Increase liquidity in pool
        IncreaseLiquidityParams memory increaseLiquidityParams = IncreaseLiquidityParams({
            tokenId: assetData.assetIds[0],
            amount0Desired: feeAmount0,
            amount1Desired: feeAmount1,
            amount0Min: 0,
            amount1Min: 1,
            deadline: block.timestamp
        });
        INonfungiblePositionManager(assetData.assets[0]).increaseLiquidity(increaseLiquidityParams);

        // Deposit NFT back
        return assetData;
    }

    /* 
    @notice Returns the onERC721Received selector.
    @dev Needed to receive ERC721 tokens.
    */
    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*
    @notice Returns the onERC1155Received selector.
    @dev Needed to receive ERC1155 tokens.
    */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
