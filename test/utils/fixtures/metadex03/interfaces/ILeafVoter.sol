// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILeafVoter {
    function MIN_REDEEM_AMOUNT() external view returns (uint256);
    // Chain lifecycle states of the LeafVoter.
    enum ChainStatus {
        None,
        Active,
        Paused,
        Suspended,
        Sunset
    }

    struct TokenSnapshot {
        uint128 staked;
        uint48 stakeEnd;
        bool isPermanent;
    }

    struct GaugeAllocation {
        address gauge;
        uint128 allocated;
        bytes data;
    }

    error ChainNotActiveOrSunset();

    // forge-lint: disable-next-line(mixed-case-function)
    function RECEIPT_TOKEN() external view returns (address);
    function chainStatus() external view returns (ChainStatus);
    function grantRole(bytes32 role, address account) external;
    function registerGauge(address gauge, bool activate) external;
    function activateGauge(address gauge) external;
    function setChainStatus(ChainStatus status) external;
    function settleGauge(address gauge) external returns (uint256 cumulativeRewardShare);
    function projectedCumulativeRewardShare(address gauge) external view returns (uint256 cumulativeRewardShare);
    function applyChainAllocation(
        uint256 tokenId,
        uint128 allocationDelta,
        // forge-lint: disable-next-line(mixed-case-variable)
        uint256 emissionsPerVP,
        // forge-lint: disable-next-line(mixed-case-variable)
        bool refreshEmissionsPerVP,
        bool refreshShape,
        TokenSnapshot calldata snapshot
    ) external;
    function applyGaugeAllocations(
        uint256 tokenId,
        uint48 expiry,
        // forge-lint: disable-next-line(mixed-case-variable)
        uint256 emissionsPerVP,
        // forge-lint: disable-next-line(mixed-case-variable)
        bool refreshEmissionsPerVP,
        bool refreshShape,
        TokenSnapshot calldata newSnapshot,
        GaugeAllocation[] calldata gauges
    ) external;
}
