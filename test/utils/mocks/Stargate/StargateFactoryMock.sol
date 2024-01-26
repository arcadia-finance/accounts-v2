/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { IPool } from "../../../../src/asset-modules/Stargate-Finance/interfaces/IPool.sol";

contract StargateFactoryMock {
    mapping(uint256 poolId => IPool pool) public getPool;

    function setPool(uint256 poolId, address pool) public {
        getPool[poolId] = IPool(pool);
    }
}
