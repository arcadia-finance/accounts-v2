/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
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
}
