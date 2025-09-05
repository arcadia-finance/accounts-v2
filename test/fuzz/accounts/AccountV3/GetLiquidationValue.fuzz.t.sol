/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getLiquidationValue" of contract "AccountV3".
 */
contract GetLiquidationValue_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getLiquidationValue(uint112 spotValue, uint8 liquidationFactor) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        spotValue = uint112(bound(spotValue, 0, type(uint112).max - 1));

        // Set Spot Value of assets (value of "stable1" is 1:1 the amount of "stable1" tokens).
        depositERC20InAccount(accountExtension, mockERC20.stable1, spotValue);

        // Invariant: "liquidationFactor" cannot exceed 100%.
        liquidationFactor = uint8(bound(liquidationFactor, 0, AssetValuationLib.ONE_4));

        // Set Liquidation factor of "stable1" for "stable1" to "liquidationFactor".
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, type(uint112).max, 0, liquidationFactor
        );

        uint256 expectedValue = uint256(spotValue) * liquidationFactor / AssetValuationLib.ONE_4;

        uint256 actualValue = accountExtension.getLiquidationValue();

        assertEq(expectedValue, actualValue);
    }
}
