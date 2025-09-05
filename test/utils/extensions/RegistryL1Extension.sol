/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1 } from "../../../src/registries/RegistryL1.sol";

contract RegistryL1Extension is RegistryL1 {
    constructor(address factory) RegistryL1(factory) { }

    function getOracleCounter() public view returns (uint256 oracleCounter_) {
        oracleCounter_ = oracleCounter;
    }

    function setOracleCounter(uint256 oracleCounter_) public {
        oracleCounter = oracleCounter_;
    }

    function getOracleToOracleModule(uint256 oracleId) public view returns (address oracleModule) {
        oracleModule = oracleToOracleModule[oracleId];
    }

    function setOracleToOracleModule(uint256 oracleId, address oracleModule) public {
        oracleToOracleModule[oracleId] = oracleModule;
    }

    function setAssetModule(address asset, address assetModule) public {
        assetToAssetInformation[asset].assetModule = assetModule;
    }

    function setAssetInformation(address asset, uint96 assetType, address assetModule) public {
        assetToAssetInformation[asset].assetType = assetType;
        assetToAssetInformation[asset].assetModule = assetModule;
    }
}
