/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeVolatileAMExtension } from "../../../utils/Extensions.sol";
import { AerodromeFactoryMock } from "../../../utils/mocks/Aerodrome/AerodromeFactoryMock.sol";
import { AerodromePoolMock } from "../../../utils/mocks/Aerodrome/AerodromePoolMock.sol";

/**
 * @notice Common logic needed by "AerodromeVolatileAM" fuzz tests.
 */
abstract contract AerodromeVolatileAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromeAMExtension internal aerodromeVolatileAM;
    AerodromeFactoryMock internal aerodromeFactoryMock;
    AerodromePoolMock internal poolMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy mocked AerodromeAM
        aeroFactoryMock = new AerodromeFactoryMock();
        poolMock = new AerodromePoolMock(18);

        // Deploy the Stargate AssetModule.
        vm.startPrank(users.creatorAddress);
        aerodromeVolatileAM = new AerodromeVoaltileAMExtension(address(registryExtension), address(aeroFactoryMock));
        registryExtension.addAssetModule(address(aerodromeVolatileAM));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
