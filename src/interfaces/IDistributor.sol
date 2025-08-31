/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IDistributor {
    function operators(address user, address operator) external view returns (uint256);
    function setClaimRecipient(address recipient, address token) external;
    function toggleOperator(address user, address operator) external;
}
