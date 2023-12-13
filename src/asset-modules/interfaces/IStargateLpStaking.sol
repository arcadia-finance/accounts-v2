/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IStargateLpStaking {
    function eToken() external view returns (address);

    function deposit(uint256 _pid, uint256 _amount) external;
}
