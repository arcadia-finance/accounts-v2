/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ChainlinkOM } from "../../../src/oracle-modules/ChainlinkOM.sol";

contract ChainlinkOMExtension is ChainlinkOM {
    constructor(address registry_) ChainlinkOM(registry_) { }

    function getInOracleModule(address oracle) public view returns (bool) {
        return inOracleModule[oracle];
    }

    function getOracleInformation(uint256 oracleId)
        public
        view
        returns (uint32 cutOffTime, uint64 unitCorrection, address oracle)
    {
        cutOffTime = oracleInformation[oracleId].cutOffTime;
        unitCorrection = oracleInformation[oracleId].unitCorrection;
        oracle = oracleInformation[oracleId].oracle;
    }
}
