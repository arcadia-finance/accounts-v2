// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { AbstractStakingModuleExtension } from "../Extensions.sol";

contract StakingModuleMock is AbstractStakingModuleExtension {
    function _stake(uint256 id, uint256 amount) internal override { }

    function _withdraw(uint256 id, uint256 amount) internal override { }

    function _claimRewards(uint256 id) internal override { }

    function _getActualRewardsBalance(uint256 id) internal view override returns (uint256 earned) { }
}
