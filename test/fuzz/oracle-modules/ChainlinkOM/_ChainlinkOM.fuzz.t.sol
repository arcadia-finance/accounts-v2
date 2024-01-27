/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { ChainlinkOMExtension } from "../../../utils/Extensions.sol";
import { OracleModule } from "../../../../src/oracle-modules/abstracts/AbstractOM.sol";

/**
 * @notice Common logic needed by all "ChainlinkOM" fuzz tests.
 */
abstract contract ChainlinkOM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        chainlinkOM = new ChainlinkOMExtension(address(registryExtension));
        registryExtension.addOracleModule(address(chainlinkOM));
        vm.stopPrank();
    }
}
