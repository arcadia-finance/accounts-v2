/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ATokenPricingModule_Fuzz_Test, Constants } from "./_ATokenPricingModule.fuzz.t.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "increaseExposure" of contract "ATokenPricingModule".
 */
contract IncreaseExposure_ATokenPricingModule_Fuzz_Test is ATokenPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ATokenPricingModule_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput, type(uint128).max);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_increaseExposure_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        aTokenPricingModule.increaseExposure(asset, 0, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_increaseExposure_OverExposure(uint128 amount, uint128 maxExposure) public {
        vm.assume(maxExposure > 0); //Asset is whitelisted
        vm.assume(amount > maxExposure);

        // Set underlying asset to max exposure
        vm.prank(erc20PricingModule.riskManager());
        aTokenPricingModule.setExposureOfAsset(address(aToken1), maxExposure);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("ATPM_IE: Exposure not in limits");
        aTokenPricingModule.increaseExposure(address(aToken1), 0, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_increaseExposure_OverExposureOfUnderlyingAsset(
        uint128 amountAToken,
        uint128 maxExposureAToken,
        uint128 maxExposureUnderlying
    ) public {
        vm.assume(maxExposureAToken > 0); //Asset is whitelisted
        vm.assume(maxExposureUnderlying < amountAToken); // We want to deposit more than the max exposure of the underlying asset
        vm.assume(amountAToken < maxExposureAToken); // We should not exceed max exposure of aToken

        // Set underlying asset to max exposure
        vm.startPrank(erc20PricingModule.riskManager());
        erc20PricingModule.setExposureOfAsset(address(mockERC20.token1), maxExposureUnderlying);
        vm.stopPrank();

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APM_IE: Exposure not in limits");
        aTokenPricingModule.increaseExposure(address(aToken1), 0, amountAToken);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseExposure(uint128 amount, uint128 maxExposure) public {
        vm.assume(amount < maxExposure);
        vm.assume(amount > 0); // Meaning maxExposure > 0 and thus asset whitelisted

        // Check exposure pre-increase
        (, uint128 preExposure) = aTokenPricingModule.exposure(address(aToken1));

        vm.prank(address(mainRegistryExtension));
        aTokenPricingModule.increaseExposure(address(aToken1), 0, amount);

        // Assert exposure increased
        (, uint128 afterExposure) = aTokenPricingModule.exposure(address(aToken1));
        assert(afterExposure > preExposure);
    }
}
