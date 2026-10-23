/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { Metadex03Fixture } from "../../../utils/fixtures/metadex03/Metadex03Fixture.f.sol";

/**
 * @notice Common logic needed by "Metadex03Staker" fuzz tests.
 */
abstract contract Metadex03Staker_Fuzz_Test is Fuzz_Test, Metadex03Fixture {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    IMetadex03V2Gauge internal metadex03Gauge;
    IMetadex03V2Pool internal metadex03Pool;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        deployMetadex03Periphery();
        deployMetadex03();
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), false);
        metadex03Gauge = createGaugeMetadex03(address(metadex03Pool));
    }
}
