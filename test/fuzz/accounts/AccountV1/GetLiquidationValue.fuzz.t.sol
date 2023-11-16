/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AssetModule } from "../../../../src/asset-modules/AbstractAssetModule.sol";
import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "getLiquidationValue" of contract "AccountV1".
 */
contract GetLiquidationValue_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getLiquidationValue(uint128 spotValue, uint8 liquidationFactor) public {
        // Given: "exposure" is strictly smaller as "maxExposure".
        spotValue = uint128(bound(spotValue, 0, type(uint128).max - 1));

        // Set Spot Value of assets (value of "stable1" is 1:1 the amount of "stable1" tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, spotValue);

        // Invariant: "liquidationFactor" cannot exceed 100%.
        liquidationFactor = uint8(bound(liquidationFactor, 0, RiskConstants.RISK_FACTOR_UNIT));

        // Set Liquidation factor of "stable1" for "stable1" to "liquidationFactor".
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint128).max, 0, liquidationFactor
        );

        uint256 expectedValue = uint256(spotValue) * liquidationFactor / RiskConstants.RISK_FACTOR_UNIT;

        uint256 actualValue = accountExtension.getLiquidationValue();

        assertEq(expectedValue, actualValue);
    }
}
