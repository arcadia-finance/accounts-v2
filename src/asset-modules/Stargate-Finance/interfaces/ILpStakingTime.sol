/**
 * Created by Pragma Labs
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { IERC20 } from "../../../interfaces/IERC20.sol";

interface ILpStakingTime {
    function eToken() external view returns (IERC20);
    function deposit(uint256 pid, uint256 amount) external;
    function withdraw(uint256 pid, uint256 amount) external;
    function pendingEmissionToken(uint256 pid, address user) external view returns (uint256);
    function userInfo(uint256 poolId, address user) external returns (uint256 amount, uint256 rewardDebt);
    function poolInfo(uint256 poolId) external view returns (address, uint256, uint256, uint256);
}
