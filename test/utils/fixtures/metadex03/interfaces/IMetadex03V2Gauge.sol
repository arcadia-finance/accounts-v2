// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03V2Gauge {
    error EmergencyWithdrawDisabled();

    function initialize(address stakingToken, address votingRewardsManager, bool isPool) external;
    function stakingToken() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function rewards(address account) external view returns (uint256);
    function depositBlock(address account) external view returns (uint256);
    function deposit(uint256 amount) external;
    function depositFor(uint256 amount, address owner) external;
    function withdraw(uint256 amount) external;
    function claimEmissions(address account, address recipient) external;
    function earned(address account) external view returns (uint256);
    function deferredEmissions(address account) external view returns (uint256);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function approvedForClaim(address account, address operator) external view returns (bool);

    function deferredReferralEmissions(address referral) external view returns (uint256);
}
