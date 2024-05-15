/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, DeployAddresses, DeployNumbers } from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract DeployAerodromeStep1 is Base_Script {
    uint80[] internal oracleAeroToUsdArr = new uint80[](1);

    constructor() {
        oracleAeroToUsdArr[0] = DeployNumbers.AeroToUsdOracleId;
    }

    function run() public {
        // Add aero-usd Chainlink oracle.
        bytes memory calldata_ = abi.encodeCall(
            chainlinkOM.addOracle,
            (DeployAddresses.oracleAeroToUsd_base, "AERO", "USD", DeployNumbers.aero_usd_cutOffTime)
        );
        addToBatch(ArcadiaSafes.owner, address(chainlinkOM), calldata_);

        // Add Aero as Primary asset.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset,
            (DeployAddresses.aero_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr))
        );
        addToBatch(ArcadiaSafes.owner, address(erc20PrimaryAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.owner);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
