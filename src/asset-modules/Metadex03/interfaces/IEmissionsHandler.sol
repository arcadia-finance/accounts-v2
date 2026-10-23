// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEmissionsHandler {
    function RECEIPT_TOKEN() external view returns (address);
    function pendingRedeems(address recipient) external view returns (uint256 pendingAmount);
}
