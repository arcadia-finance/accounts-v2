/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setMaxExposureOfAsset" of contract "AbstractPrimaryPricingModule".
 */
contract setMaxExposureOfAsset_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMaxExposureOfAsset_NonRiskManager(
        address unprivilegedAddress_,
        address asset,
        uint96 assetId,
        uint128 maxExposure
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        pricingModule.setMaxExposureOfAsset(asset, assetId, maxExposure);
        vm.stopPrank();
    }

    function testFuzz_Revert_setMaxExposureOfAsset_maxExposureNotInLimits(
        uint256 maxExposure,
        address asset,
        uint96 assetId
    ) public {
        vm.assume(maxExposure > type(uint128).max);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("APPM_SEA: Max Exp. not in limits");
        pricingModule.setMaxExposureOfAsset(asset, assetId, maxExposure);
        vm.stopPrank();
    }

    function testFuzz_Success_setMaxExposureOfAsset(address asset, uint128 maxExposure, uint96 assetId) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit MaxExposureSet(asset, maxExposure);
        pricingModule.setMaxExposureOfAsset(asset, assetId, maxExposure);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (uint128 actualMaxExposure,) = pricingModule.exposure(assetKey);
        assertEq(actualMaxExposure, maxExposure);
    }
}
