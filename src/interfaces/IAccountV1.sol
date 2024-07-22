/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IAccountV1 {
    function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external;

    function openMarginAccount(address newCreditor) external;

    function owner() external returns (address owner_);
}
