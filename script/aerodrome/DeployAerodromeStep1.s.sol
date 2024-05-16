/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, Oracles, OracleIds, CutOffTimes } from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract DeployAerodromeStep1 is Base_Script {
    uint80[] internal oracleAeroToUsdArr = new uint80[](1);

    constructor() {
        oracleAeroToUsdArr[0] = OracleIds.AERO_USD;
    }

    function run() public {
        // Add aero-usd Chainlink oracle.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.AERO_USD, "AERO", "USD", CutOffTimes.AERO_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add Aero as Primary asset.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.AERO, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
