// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactoryRegistry {
    function registerFactories(address gaugeFactory, address targetFactory) external;
    function registerTarget(address target) external;
    function registerGauge(address gauge, address gaugeFactory, address rewards, address target) external;
    function emissionCap(address gauge) external view returns (uint128 cap);
    function gaugeToTarget(address gauge) external view returns (address target);
    function leafVoter() external view returns (address voter);
    function targetToGauge(address target) external view returns (address gauge);
}
