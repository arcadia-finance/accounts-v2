// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactoryRegistry {
    function gaugeToFactory(address gauge) external view returns (address);

    function gaugeToTarget(address gauge) external view returns (address);
}
