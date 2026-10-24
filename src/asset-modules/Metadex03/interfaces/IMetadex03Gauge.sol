// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03Gauge {
    function stakingToken() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function depositBlock(address account) external view returns (uint256);
    function isPenaltyActive(address account) external view returns (bool);
    function deferredEmissions(address account) external view returns (uint256);
    function deposit(uint256 amount) external;
    function emergencyWithdraw(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawFrom(uint256 amount, address account) external;
    function setApprovalForAll(address operator, bool approved) external;
    function approveForClaim(address operator, bool approved) external;
    function claimEmissions(address account, address recipient) external;
    function earned(address account) external view returns (uint256);
}
