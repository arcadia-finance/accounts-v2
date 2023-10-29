/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMaxUsdExposureProtocol" of contract "AbstractDerivedPricingModule".
 */
contract SetMaxExposure_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMaxUsdExposureProtocol_NonRiskManager(
        address unprivilegedAddress_,
        uint256 maxExposureInUsd
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        derivedPricingModule.setMaxUsdExposureProtocol(maxExposureInUsd);
        vm.stopPrank();
    }

    function testFuzz_Success_setMaxUsdExposureProtocol(uint256 maxExposureInUsd) public {
        vm.prank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit MaxUsdExposureProtocolSet(maxExposureInUsd);
        derivedPricingModule.setMaxUsdExposureProtocol(maxExposureInUsd);

        assertEq(derivedPricingModule.maxUsdExposureProtocol(), maxExposureInUsd);
    }
}
