/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "AbstractPrimaryPricingModule".
 */
contract SetRiskParameters_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The maximum collateral factor of an asset for a creditor, 2 decimals precision.
    uint16 internal constant MAX_COLLATERAL_FACTOR = 100;
    // The maximum liquidation factor of an asset for a creditor, 2 decimals precision.
    uint16 internal constant MAX_LIQUIDATION_FACTOR = 100;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonMainRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_CollateralFactorNotInLimits(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, MAX_COLLATERAL_FACTOR + 1, type(uint16).max));

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_SRP: Coll.Fact not in limits");
        pricingModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_LiquidationFactorNotInLimits(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, MAX_COLLATERAL_FACTOR));
        liquidationFactor = uint16(bound(liquidationFactor, MAX_LIQUIDATION_FACTOR + 1, type(uint16).max));

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_SRP: Liq.Fact not in limits");
        pricingModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, MAX_COLLATERAL_FACTOR));
        liquidationFactor = uint16(bound(liquidationFactor, 0, MAX_LIQUIDATION_FACTOR));

        vm.prank(address(mainRegistryExtension));
        pricingModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (, uint128 actualMaxExposure, uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            pricingModule.riskParams(creditor, assetKey);
        assertEq(actualMaxExposure, maxExposure);
        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationFactor, liquidationFactor);
    }
}
