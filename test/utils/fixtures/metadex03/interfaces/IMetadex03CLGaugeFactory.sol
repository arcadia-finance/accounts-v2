// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03CLGaugeFactory {
    function createGauge(address target, bytes calldata factoryData) external returns (address gauge, address rewards);
    function isGauge(address gauge) external view returns (bool);
    function implementation() external view returns (address);
    function setPenaltyConfig(uint256 minStakeBlocks, uint256 penaltyRate) external;
    function setMinStakeBlocks(address gauge, uint256 minStakeBlocks) external;
    function setMaxShareCap(uint256 cap) external;
    function setReferralConfig(address gauge, address referral, uint256 share) external;
    function setClGaugeTape(address clGaugeTape, uint32 gasLimit) external;
    function setEmergencyWithdrawEnabled(bool enabled) external;
    // forge-lint: disable-next-line(mixed-case-function)
    function EMERGENCY_WITHDRAW_ROLE() external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function referralConfig(address gauge) external view returns (address referral, uint256 share);
}
