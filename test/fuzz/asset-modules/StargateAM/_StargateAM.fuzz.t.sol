/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StargateAMExtension } from "../../../utils/Extensions.sol";
import { StargateFactoryMock } from "../../../utils/mocks/Stargate/StargateFactoryMock.sol";
import { StargatePoolMock } from "../../../utils/mocks/Stargate/StargatePoolMock.sol";

/**
 * @notice Common logic needed by "StargateAM" fuzz tests.
 */
abstract contract StargateAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StargateAMExtension internal stargateAssetModule;
    StargateFactoryMock internal sgFactoryMock;
    StargatePoolMock internal poolMock;

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
