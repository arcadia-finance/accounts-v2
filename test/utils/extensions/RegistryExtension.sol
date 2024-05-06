/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry } from "../../../src/Registry.sol";

contract RegistryExtension is Registry {
    constructor(address factory, address sequencerUptimeOracle_) Registry(factory, sequencerUptimeOracle_) { }

    function isSequencerDown(address creditor) public view returns (bool success, bool sequencerDown) {
        return _isSequencerDown(creditor);
    }

    function getSequencerUptimeOracle() public view returns (address sequencerUptimeOracle_) {
        sequencerUptimeOracle_ = sequencerUptimeOracle;
    }

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
