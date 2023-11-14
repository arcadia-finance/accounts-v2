// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { OracleModule } from "../../../src/oracle-modules/AbstractOracleModule.sol";

contract OracleModuleMock is OracleModule {
    mapping(address => bool) public inOracleModule;

    mapping(uint256 => bool) internal isActive_;

    mapping(uint256 => uint256) internal rate;

    constructor(address mainRegistry_) OracleModule(mainRegistry_) { }

    function isActive(uint256 oracleId) external view override returns (bool) {
        return isActive_[oracleId];
    }

    function setIsActive(uint256 oracleId, bool active) external {
        isActive_[oracleId] = active;
    }

    function decommissionOracle(uint256 oracleId) external override returns (bool) { }

    function getRate(uint256 oracleId) external view override returns (uint256 rate_) {
        rate_ = rate[oracleId];
    }

    function setRate(uint256 oracleId, uint256 rate_) external {
        rate[oracleId] = rate_;
    }

    function setOracle(uint256 oracleId, bytes16 baseAsset, bytes16 quoteAsset, bool active) external {
        assetPair[oracleId] = AssetPair({ baseAsset: baseAsset, quoteAsset: quoteAsset });
        isActive_[oracleId] = active;
    }
}
