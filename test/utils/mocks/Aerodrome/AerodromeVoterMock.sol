/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract AerodromeVoterMock {
    address public ve;
    mapping(address pool => bool isGauge) public isGauge;
    mapping(address gauge => bool) public isAlive;

    function setGauge(address gauge) public {
        isGauge[gauge] = true;
    }

    function setAlive(address gauge) public {
        isAlive[gauge] = true;
    }

    function factoryRegistry() public returns (address factoryRegistry_) { }
}
