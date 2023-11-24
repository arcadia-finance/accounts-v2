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
     * @param actionHandlerData A bytes object containing one actionData struct, an address array and a bytes array.
     * @return resultData An actionAssetData struct with the balances of this ActionMultiCall address.
     */

    function executeAction(bytes calldata actionHandlerData) external returns (ActionData memory);
}
