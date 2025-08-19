/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

contract VoterMock {
    address public factoryRegistry;
    address public ve;
    mapping(address gauge => bool isGauge) public isGauge;
    mapping(address gauge => bool) public isAlive;
    mapping(address => address) public gauges;

    constructor(address factoryRegistry_) {
        factoryRegistry = factoryRegistry_;
    }

    function setGauge(address pool, address gauge) public {
        isGauge[gauge] = true;
        gauges[pool] = gauge;
    }

    function setAlive(address gauge, bool _isAlive) public {
        isAlive[gauge] = _isAlive;
    }
}
