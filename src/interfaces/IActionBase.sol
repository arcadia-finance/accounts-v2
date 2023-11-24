/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

// Struct with information to pass to and from actionHandlers.
struct ActionData {
    // Array of the contract addresses of the assets.
    address[] assets;
    // Array of the IDs of the assets.
    uint256[] assetIds;
    // Array with the amounts of the assets.
    uint256[] assetAmounts;
    // Array with the types of the assets.
    uint256[] assetTypes;
}

interface IActionBase {
    /**
     * @notice Calls a series of addresses with arbitrary calldata.
     * @param depositData Struct with information to pass to the actionHandler.
     * @param to An array of contracts to call in the actionHandler.
     * @param data The calldata for the "to" contracts.
     * @return resultData An actionAssetData struct with the balances of this ActionMultiCall address.
     */

    function executeAction(ActionData memory depositData, address[] memory to, bytes[] memory data)
        external
        returns (ActionData memory);
}
