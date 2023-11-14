/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by all "FloorERC1155PricingModule" fuzz tests.
 */
abstract contract FloorERC1155PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes32 internal oraclesSft2ToUsd;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        chainlinkOM.addOracle(address(mockOracles.sft2ToUsd), "SFT2", "USD");

        uint80[] memory oracleSft2ToUsdArr = new uint80[](1);
        oracleSft2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.sft2ToUsd)));
        oraclesSft2ToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleSft2ToUsdArr);
    }
}
