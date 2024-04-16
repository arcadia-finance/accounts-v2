/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract AerodromeFactoryMock {
    mapping(address pool => bool isPool) public isPool;

    function setPool(address pool) public {
        isPool[pool] = true;
    }
}
