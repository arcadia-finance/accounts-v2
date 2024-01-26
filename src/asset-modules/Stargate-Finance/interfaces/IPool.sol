/**
 * Created by Pragma Labs
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IPool {
    function amountLPtoLD(uint256 _amountLP) external view returns (uint256);
    function token() external view returns (address);
}
