/**
 * Created by Pragma Labs
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface IPool {
    /// forge-lint: disable-next-item(mixed-case-function,mixed-case-variable)
    function amountLPtoLD(uint256 amountLP) external view returns (uint256);
    function token() external view returns (address);
}
