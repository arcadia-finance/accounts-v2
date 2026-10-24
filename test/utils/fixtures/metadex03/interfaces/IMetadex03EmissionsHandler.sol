// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03EmissionsHandler {
    function pendingRedeems(address recipient) external view returns (uint256 pendingAmount);
}
