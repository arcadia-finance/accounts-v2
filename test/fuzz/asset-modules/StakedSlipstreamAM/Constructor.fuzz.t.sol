/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

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

    function testFuzz_success_constructor() public {
        stakedSlipstreamAM = new StakedSlipstreamAMExtension(
            address(registry), address(slipstreamPositionManager), address(voter), address(AERO)
        );

        assertEq(stakedSlipstreamAM.REGISTRY(), address(registry));
        assertEq(stakedSlipstreamAM.getNonfungiblePositionManager(), address(slipstreamPositionManager));
        assertEq(stakedSlipstreamAM.getAeroVoter(), address(voter));
        assertEq(address(stakedSlipstreamAM.REWARD_TOKEN()), address(AERO));
        assertEq(stakedSlipstreamAM.getCLFactory(), address(cLFactory));
    }
}
