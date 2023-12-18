/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StargateAssetModule } from "../../../../src/asset-modules/StargateAssetModule.sol";
import { LPStakingTimeMock } from "../../../utils/mocks/Stargate/StargateLpStakingMock.sol";
import { StargatePoolMock } from "../../../utils/mocks/Stargate/StargatePoolMock.sol";

/**
 * @notice Common logic needed by "StargateAssetModule" fuzz tests.
 */
abstract contract StargateAssetModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StargatePoolMock internal stargatePoolMock;
    StargateAssetModule internal stargateAssetModule;
    LPStakingTimeMock internal lpStakingTimeMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        stargatePoolMock = new StargatePoolMock();
        lpStakingTimeMock = new LPStakingTimeMock();
        stargateAssetModule = new StargateAssetModule(address(registryExtension), address(lpStakingTimeMock));

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
