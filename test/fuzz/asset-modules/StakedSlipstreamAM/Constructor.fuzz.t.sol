/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAMExtension } from "../../../utils/extensions/StakedSlipstreamAMExtension.sol";

/**
 * @notice Fuzz tests for the constructor of contract "StakedSlipstreamAM".
 */
contract Constructor_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedSlipstreamAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_constructor_RewardTokenNotAllowed() public {
        // Given: No asset module is set for the rewardToken
        registryExtension.setAssetModule(AERO, address(0));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotAllowed.selector);
        new StakedSlipstreamAMExtension(
            address(registryExtension), address(nonfungiblePositionManager), address(voter), address(AERO)
        );
    }

    function testFuzz_success_constructor() public {
        new StakedSlipstreamAMExtension(
            address(registryExtension), address(nonfungiblePositionManager), address(voter), address(AERO)
        );
    }
}
