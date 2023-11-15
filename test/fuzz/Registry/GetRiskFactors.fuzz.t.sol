/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { RiskConstants } from "../../../src/libraries/RiskConstants.sol";
import { Utils } from "../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "Registry".
 */
contract GetRiskFactors_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRiskFactors(
        address creditor,
        address[2] memory assets,
        uint256[2] memory assetIds,
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors
    ) public {
        // Given: id's are smaller or equal to type(uint96).max.
        assetIds[0] = bound(assetIds[0], 0, type(uint96).max);
        assetIds[1] = bound(assetIds[1], 0, type(uint96).max);

        // And: Risk factors are below max risk factor.
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, RiskConstants.RISK_FACTOR_UNIT));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, RiskConstants.RISK_FACTOR_UNIT));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], 0, RiskConstants.RISK_FACTOR_UNIT));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], 0, RiskConstants.RISK_FACTOR_UNIT));

        // And: Underlying assets are in primaryAssetModule.
        registryExtension.setAssetModuleForAsset(assets[0], address(primaryAssetModule));
        registryExtension.setAssetModuleForAsset(assets[1], address(primaryAssetModule));
        vm.startPrank(address(registryExtension));
        primaryAssetModule.setRiskParameters(
            creditor, assets[0], assetIds[0], 0, collateralFactors[0], liquidationFactors[0]
        );
        primaryAssetModule.setRiskParameters(
            creditor, assets[1], assetIds[1], 0, collateralFactors[1], liquidationFactors[1]
        );
        vm.stopPrank();

        // When: "getRiskFactors" is called.
        (uint16[] memory actualCollateralFactors, uint16[] memory actualLiquidationFactors) = registryExtension
            .getRiskFactors(creditor, Utils.castArrayStaticToDynamic(assets), Utils.castArrayStaticToDynamic(assetIds));

        // Then: Transaction returns correct risk factors.
        assertEq(actualCollateralFactors[0], collateralFactors[0]);
        assertEq(actualCollateralFactors[1], collateralFactors[1]);

        assertEq(actualLiquidationFactors[0], liquidationFactors[0]);
        assertEq(actualLiquidationFactors[1], liquidationFactors[1]);
    }
}
