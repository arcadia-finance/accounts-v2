/**
 * Created by Pragma Labs
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface IRouter {
    function addLiquidity(uint256 poolId, uint256 amount, address to) external;
    /// forge-lint: disable-next-item(mixed-case-variable)
    function instantRedeemLocal(uint16 poolId, uint256 amountLp, address to) external returns (uint256 amountSD);
}
