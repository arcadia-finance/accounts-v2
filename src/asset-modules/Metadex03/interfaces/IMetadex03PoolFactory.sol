// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03PoolFactory {
    function isPool(address pool) external view returns (bool);
}
