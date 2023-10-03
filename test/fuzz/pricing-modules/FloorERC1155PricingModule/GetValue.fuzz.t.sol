/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC1155PricingModule_Fuzz_Test } from "./_FloorERC1155PricingModule.fuzz.t.sol";

import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

import { IPricingModule_New } from "../../../../src/interfaces/IPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "FloorERC1155PricingModule".
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
            address(mockERC1155.sft2), 1, oracleSft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
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

        IPricingModule_New.GetValueInput memory getValueInput = IPricingModule_New.GetValueInput({
            asset: address(mockERC1155.sft2),
            assetId: 1,
            assetAmount: amountSft2,
            baseCurrency: UsdBaseCurrencyID
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

        IPricingModule_New.GetValueInput memory getValueInput = IPricingModule_New.GetValueInput({
            asset: address(mockERC1155.sft2),
            assetId: 0,
            assetAmount: amountSft2,
            baseCurrency: UsdBaseCurrencyID
        });
        // When: getValue called
        (uint256 actualValueInUsd,,) = floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
