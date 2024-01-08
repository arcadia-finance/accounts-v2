/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StargateAssetModule } from "../../../../src/asset-modules/StargateAssetModule.sol";
import { StargateAssetModuleExtension } from "../../../utils/Extensions.sol";
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

    StargatePoolMock internal poolMock;
    StargateAssetModuleExtension internal stargateAssetModule;
    LPStakingTimeMock internal lpStakingTimeMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        poolMock = new StargatePoolMock(18);
        lpStakingTimeMock = new LPStakingTimeMock();
        stargateAssetModule = new StargateAssetModuleExtension(address(registryExtension), address(lpStakingTimeMock));

        registryExtension.addAssetModule(address(stargateAssetModule));
        stargateAssetModule.initialize();

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
