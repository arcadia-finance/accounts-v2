/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { IPool } from "./IPool.sol";

interface ISGFactory {
    function getPool(uint256 poolId) external view returns (IPool);
}
