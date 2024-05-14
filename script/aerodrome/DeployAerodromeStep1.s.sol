/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import {
    ArcadiaContracts,
    ArcadiaSafes,
    DeployAddresses,
    DeployNumbers,
    DeployRiskConstantsBase
} from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";
import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";
import { SafeTransactionBuilder } from "../utils/SafeTransactionBuilder.sol";

contract DeployAerodromeStep1 is Base_Script, SafeTransactionBuilder {
    ERC20 internal aero = ERC20(DeployAddresses.aero_base);

    uint80 internal oracleAeroToUsdId = 8;
    uint80[] internal oracleAeroToUsdArr = new uint80[](1);

    constructor() {
        oracleAeroToUsdArr[0] = oracleAeroToUsdId;
    }

    // Add Aero as Primary asset.
    function run() public {
        bytes memory calldata_ = abi.encodeCall(
            chainlinkOM.addOracle,
            (DeployAddresses.oracleAeroToUsd_base, "AERO", "USD", DeployNumbers.aero_usd_cutOffTime)
        );
        addToBatch(ArcadiaSafes.owner, address(chainlinkOM), calldata_);

        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset,
            (DeployAddresses.aero_base, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr))
        );
        addToBatch(ArcadiaSafes.owner, address(erc20PrimaryAM), calldata_);

        bytes memory data = createBatchedData(ArcadiaSafes.owner);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
