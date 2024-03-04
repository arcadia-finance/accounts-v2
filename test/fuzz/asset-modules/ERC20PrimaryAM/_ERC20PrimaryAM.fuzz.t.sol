/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";

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

        vm.prank(users.creatorAddress);
        chainlinkOM.addOracle(address(mockOracles.token4ToUsd), "TOKEN4", "USD", 2 days);

        uint80[] memory oracleToken4ToUsdArr = new uint80[](1);
        oracleToken4ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token4ToUsd)));
        oraclesToken4ToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken4ToUsdArr);
    }
}
