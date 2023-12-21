/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

// Struct with information to pass to and from the actionTarget.
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
     * @notice Calls an external target contract with arbitrary calldata.
     * @param actionTargetData A bytes object containing the encoded input for the actionTarget.
     * @return resultData An actionAssetData struct with the final balances of this actionTarget contract.
     */
    function executeAction(bytes calldata actionTargetData) external returns (ActionData memory);
}
