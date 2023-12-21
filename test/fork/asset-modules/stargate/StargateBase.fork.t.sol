/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../../Fork.t.sol";

import { ILpStakingTime } from "../../../../src/asset-modules/interfaces/stargate/ILpStakingTime.sol";
import { IRouter } from "../../../../src/asset-modules/interfaces/stargate/IRouter.sol";
import { StargateAssetModule } from "../../../../src/asset-modules/StargateAssetModule.sol";

/**
 * @notice Base test file for Stargate Asset-Module fork tests.
 */
contract StargateBase_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    IRouter public router = IRouter(0x45f1A95A4D3f3836523F5c83673c797f4d4d263B);
    ILpStakingTime public lpStakingTime = ILpStakingTime(0x06Eb48763f117c7Be887296CDcdfad2E4092739C);

    StargateAssetModule public stargateAssetModule;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Fork_Test.setUp();

        // Deploy StargateAssetModule.
        vm.startPrank(users.creatorAddress);
        stargateAssetModule = new StargateAssetModule(address(registryExtension), address(lpStakingTime));

        // Add Asset-Module to the registry and initialize.
        registryExtension.addAssetModule(address(stargateAssetModule));
        stargateAssetModule.initialize();

        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function assertInRange(uint256 actualValue, uint256 expectedValue, uint8 precision) internal {
        if (expectedValue == 0) {
            assertEq(actualValue, expectedValue);
        } else {
            vm.assume(expectedValue > 10 ** (2 * precision));
            assertGe(actualValue * (10 ** precision + 1) / 10 ** precision, expectedValue);
            assertLe(actualValue * (10 ** precision - 1) / 10 ** precision, expectedValue);
        }
    }
}
