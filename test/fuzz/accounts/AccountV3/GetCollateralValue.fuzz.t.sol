/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getCollateralValue" of contract "AccountV3".
 */
contract GetCollateralValue_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
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
    function testFuzz_Success_getCollateralValue(uint112 spotValue, uint8 collateralFactor) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        spotValue = uint112(bound(spotValue, 0, type(uint112).max - 1));

        // Set Spot Value of assets (value of "stable1" is 1:1 the amount of "stable1" tokens).
        depositERC20InAccount(accountExtension, mockERC20.stable1, spotValue);

        // Invariant: "collateralFactor" cannot exceed 100%.
        collateralFactor = uint8(bound(collateralFactor, 0, AssetValuationLib.ONE_4));

        // Set Collateral factor of "stable1" for "stable1" to "collateralFactor".
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            collateralFactor,
            uint16(AssetValuationLib.ONE_4)
        );

        uint256 expectedValue = uint256(spotValue) * collateralFactor / AssetValuationLib.ONE_4;

        uint256 actualValue = accountExtension.getCollateralValue();

        assertEq(expectedValue, actualValue);
    }
}
