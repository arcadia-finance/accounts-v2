/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { IERC20 } from "../interfaces/IERC20.sol";
import { IERC1155 } from "../interfaces/IERC1155.sol";
import { ERC721TokenReceiver } from "../../lib/solmate/src/tokens/ERC721.sol";
import { IPermit2 } from "../interfaces/IPermit2.sol";
import { IActionBase, ActionData } from "../interfaces/IActionBase.sol";

/**
 * @title Generic Multicall action
 * @author Pragma Labs
 * @notice Calls any external contract with arbitrary data.
 * @dev Only calls are used, no delegatecalls.
 * @dev This address will approve random addresses. Do not store any funds on this address!
 */
contract ActionMultiCall is IActionBase, ERC721TokenReceiver {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    address[] internal mintedAssets;
    uint256[] internal mintedIds;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error LengthMismatch();
    error InsufficientAmountOut();
    error OnlyInternal();
    error LeftoverNfts();

    /* //////////////////////////////////////////////////////////////
                            ACTION LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param actionData A bytes object containing one actionData struct, an address array and a bytes array.
     * @return depositData The modified `ActionData` struct representing the final state of the `depositData` after executing the action.
     */
    function executeAction(bytes calldata actionData) external override returns (ActionData memory) {
        (ActionData memory depositData, address[] memory to, bytes[] memory data) =
            abi.decode(actionData, (ActionData, address[], bytes[]));

        uint256 callLength = to.length;
        if (callLength != data.length) revert LengthMismatch();

        for (uint256 i; i < callLength; ++i) {
            (bool success, bytes memory result) = to[i].call(data[i]);
            require(success, string(result));
        }

        for (uint256 i; i < depositData.assets.length; ++i) {
            if (depositData.assetTypes[i] == 0) {
                depositData.assetAmounts[i] = IERC20(depositData.assets[i]).balanceOf(address(this));
            } else if (depositData.assetTypes[i] == 1) {
                // If the amount is 0, we minted a new NFT.
                if (depositData.assetAmounts[i] == 0) {
                    depositData.assetAmounts[i] = 1;

                    // Start taking data from the minted arrays.
                    // We can overwrite address and ID from depositData.
                    // All assets with type == 1 and amount == 0 are stored in the minted arrays.
                    depositData.assetIds[i] = mintedIds[mintedIds.length - 1];
                    depositData.assets[i] = mintedAssets[mintedAssets.length - 1];
                    mintedIds.pop();
                    mintedAssets.pop();
                }
            } else if (depositData.assetTypes[i] == 2) {
                depositData.assetAmounts[i] =
                    IERC1155(depositData.assets[i]).balanceOf(address(this), depositData.assetIds[i]);
            }
        }

        // If any assets were minted and are left in this contract, revert.
        if (mintedIds.length > 0 || mintedAssets.length > 0) revert LeftoverNfts();

        return depositData;
    }

    /* //////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Repays an exact amount to a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset that is being repaid.
     * @param account The contract address of the Account for which the debt is being repaid.
     * @param amount The amount of debt to repay.
     * @dev Can be called as one of the calls in executeAction, but fetches the actual contract balance after other DeFi interactions.
     */
    function executeRepay(address creditor, address asset, address account, uint256 amount) external {
        if (amount < 1) amount = IERC20(asset).balanceOf(address(this));

        (bool success, bytes memory data) =
            creditor.call(abi.encodeWithSignature("repay(uint256,address)", amount, account));
        require(success, string(data));
    }

    /**
     * @notice Checks the current balance of an asset and ensures it's larger than a required amount.
     * @param asset The token contract address of the asset that is being checked.
     * @param minAmountOut The amount of tokens this contract needs to hold at least to succeed.
     * @dev Can be called as one of the calls in executeAction.
     */
    function checkAmountOut(address asset, uint256 minAmountOut) external view {
        if (IERC20(asset).balanceOf(address(this)) < minAmountOut) revert InsufficientAmountOut();
    }

    /**
     * @notice Helper function to mint an LP token and return the ID for later usage.
     * @param to The contract address of the LP token.
     * @param data The data to call the lp contract with.
     * @dev Asset address and ID is temporarily stored in this contract.
     */
    function mintUniV3LP(address to, bytes memory data) external {
        if (msg.sender != address(this)) revert OnlyInternal();
        (bool success, bytes memory result) = to.call(data);
        require(success, string(result));

        (uint256 tokenId,,,) = abi.decode(result, (uint256, uint128, uint256, uint256));
        mintedAssets.push(to);
        mintedIds.push(tokenId);
    }
}
