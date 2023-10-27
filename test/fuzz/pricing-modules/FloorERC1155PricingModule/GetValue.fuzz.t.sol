/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

import { Constants } from "../../../utils/Constants.sol";
import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "FloorERC1155PricingModule".
 */
contract GetValue_FloorERC1155PricingModule_Fuzz_Test is FloorERC1155PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC1155PricingModule_Fuzz_Test.setUp();

        // Add Sft2 (which has an oracle directly to usd).
        vm.prank(users.creatorAddress);
        floorERC1155PricingModule.addAsset(
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft2), 1, type(uint128).max, 0, 0
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(uint256 amountSft2, uint256 rateSft2ToUsd) public {
        // No Overflow OracleHub
        vm.assume(rateSft2ToUsd <= type(uint256).max / Constants.WAD);
        vm.assume(rateSft2ToUsd > 0);

        vm.assume(
            amountSft2 > type(uint256).max / (rateSft2ToUsd * Constants.WAD / 10 ** Constants.erc1155OracleDecimals)
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.sft2ToUsd.transmit(int256(rateSft2ToUsd));

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(mockERC1155.sft2),
            assetId: 1,
            assetAmount: amountSft2,
            baseCurrency: UsdBaseCurrencyID,
            creditor: address(creditorUsd)
        });

        // When: getValue called
        // Then: getValue should be reverted
        vm.expectRevert(stdError.arithmeticError);
        floorERC1155PricingModule.getValue(getValueInput);
    }

    function testFuzz_Success_getValue(uint256 amountSft2, uint256 rateSft2ToUsd) public {
        // No Overflow OracleHub
        vm.assume(rateSft2ToUsd <= type(uint256).max / Constants.WAD);

        if (rateSft2ToUsd != 0) {
            vm.assume(
                amountSft2
                    <= type(uint256).max / (Constants.WAD * rateSft2ToUsd / 10 ** Constants.erc1155OracleDecimals)
            );
        }

        uint256 expectedValueInUsd = Constants.WAD * rateSft2ToUsd / 10 ** Constants.erc1155OracleDecimals * amountSft2;

        vm.prank(users.defaultTransmitter);
        mockOracles.sft2ToUsd.transmit(int256(rateSft2ToUsd));

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(mockERC1155.sft2),
            assetId: 0,
            assetAmount: amountSft2,
            baseCurrency: UsdBaseCurrencyID,
            creditor: address(creditorUsd)
        });
        // When: getValue called
        (uint256 actualValueInUsd,,) = floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
