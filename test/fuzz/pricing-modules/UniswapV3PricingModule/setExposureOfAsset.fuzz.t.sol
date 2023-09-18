/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setExposureOfAsset" of contract "UniswapV3PricingModule".
 */
contract SetExposureOfAsset_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setExposureOfAsset_NonRiskManager(
        address unprivilegedAddress_,
        address asset,
        uint128 maxExposure
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        uniV3PricingModule.setExposureOfAsset(asset, maxExposure);
        vm.stopPrank();
    }

    function testFuzz_Revert_setExposureOfAsset_UnknownAsset(uint128 maxExposure) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PMUV3_SEOA: Unknown asset");
        uniV3PricingModule.setExposureOfAsset(address(mockERC20.token3), maxExposure);
        vm.stopPrank();
    }

    function testFuzz_Success_setExposureOfAsset(uint128 maxExposure) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit MaxExposureSet(address(mockERC20.token1), maxExposure);
        uniV3PricingModule.setExposureOfAsset(address(mockERC20.token1), maxExposure);
        vm.stopPrank();

        (uint128 actualMaxExposure,) = uniV3PricingModule.exposure(address(mockERC20.token1));
        assertEq(actualMaxExposure, maxExposure);
    }
}
