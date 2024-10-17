/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

interface ICLGaugeFactory {
    function createGauge(address, address _pool, address _feesVotingReward, address _rewardToken, bool _isPool)
        external
        returns (address _gauge);

    function setNonfungiblePositionManager(address nft) external;
}
