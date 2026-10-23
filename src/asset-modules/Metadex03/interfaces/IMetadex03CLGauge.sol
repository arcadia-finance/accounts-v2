// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03CLGauge {
    function pool() external view returns (address);
    function deposit(uint256 tokenId) external;
    function emergencyWithdraw(uint256 tokenId) external;
    function withdraw(uint256 tokenId) external;
    function claimEmissions(address account, address recipient, uint256[] calldata tokenIds) external;
    function earned(address account, uint256[] memory tokenIds) external view returns (uint256);
    function deferredEmissions(address account) external view returns (uint256);
    function deferredReferralEmissions(address referral) external view returns (uint256);
}
