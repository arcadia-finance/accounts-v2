// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03V2PoolFactory {
    function createPool(address tokenA, address tokenB) external returns (address pool);
    function isPool(address pool) external view returns (bool);
}
