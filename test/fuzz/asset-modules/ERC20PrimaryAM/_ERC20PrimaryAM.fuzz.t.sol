/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "ERC20PrimaryAM" fuzz tests.
 */
abstract contract ERC20PrimaryAM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes32 internal oraclesToken4ToUsd;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.owner);
        chainlinkOM.addOracle(address(mockOracles.token4ToUsd), "TOKEN4", "USD", 2 days);

        uint80[] memory oracleToken4ToUsdArr = new uint80[](1);
        oracleToken4ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token4ToUsd)));
        oraclesToken4ToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken4ToUsdArr);
    }
}
