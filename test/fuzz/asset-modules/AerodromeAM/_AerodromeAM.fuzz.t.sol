/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeAMExtension } from "../../../utils/Extensions.sol";
import { AerodromeFactoryMock } from "../../../utils/mocks/Aerodrome/AerodromeFactoryMock.sol";
import { AerodromePoolMock } from "../../../utils/mocks/Aerodrome/AerodromePoolMock.sol";

/**
 * @notice Common logic needed by "StargateAM" fuzz tests.
 */
abstract contract AerodromeAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AerodromeAMExtension internal aerodromeAssetModule;
    AerodromeFactoryMock internal aerodromeFactoryMock;
    AerodromePoolMock internal poolMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy mocked Stargate.
        sgFactoryMock = new StargateFactoryMock();
        poolMock = new StargatePoolMock(18);

        // Deploy the Stargate AssetModule.
        vm.startPrank(users.creatorAddress);
        stargateAssetModule = new StargateAMExtension(address(registryExtension), address(sgFactoryMock));
        registryExtension.addAssetModule(address(stargateAssetModule));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
