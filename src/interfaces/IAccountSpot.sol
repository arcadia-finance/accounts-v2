/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IAccountSpot {
    function withdraw(
        address[] memory assets,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes
    ) external;

    function owner() external returns (address owner_);
}
