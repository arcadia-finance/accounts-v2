/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAM_Fuzz_Test } from "./_AbstractPrimaryAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "AbstractPrimaryAM".
 */
contract GetRiskFactors_AbstractPrimaryAM_Fuzz_Test is AbstractPrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRiskFactors(
        address creditor,
        address asset,
        uint96 assetId,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        // And: Risk factors are below max risk factor.
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        // And: Underlying asset is in primaryAM.
        vm.prank(address(registryExtension));
        assetModule.setRiskParameters(creditor, asset, assetId, 0, collateralFactor, liquidationFactor);

        // When: "getRiskFactors" is called.
        (uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            assetModule.getRiskFactors(creditor, asset, assetId);

        // Then: Transaction returns correct risk factors.
        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationFactor, liquidationFactor);
    }
}
