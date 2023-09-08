/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "./Fuzz.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";
import { FloorERC1155PricingModule_UsdOnly } from "../../pricing-modules/FloorERC1155PricingModule_UsdOnly.sol";
import { stdError } from "../../../lib/forge-std/src/StdError.sol";

contract FloorERC1155PricingModule_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_getValue(uint80 amountERC1155, uint72 rateERC1155ToToken1) public {
        // Does not test on overflow, test to check if function correctly returns value in Usd
        uint256 expectedValueInUsd = (
            uint256(amountERC1155) * uint256(rateERC1155ToToken1) * rates.token1ToUsd * Constants.WAD
        ) / 10 ** (Constants.erc1155OracleDecimals + Constants.tokenOracleDecimals);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.erc1155ToToken1.transmit(int256(uint256(rateERC1155ToToken1)));
        vm.stopPrank();

        IPricingModule_UsdOnly.GetValueInput memory getValueInput = IPricingModule_UsdOnly.GetValueInput({
            asset: address(mockERC1155.erc1155),
            assetId: 0,
            assetAmount: amountERC1155,
            baseCurrency: UsdBaseCurrencyID
        });
        // When: getValue called
        (uint256 actualValueInUsd,,) = floorERC1155PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }

    function testRevert_Fuzz_getValue_Overflow(uint256 amountERC1155, uint256 rateERC1155ToToken1New) public {
        // Given: rateInterleaveToEthNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD and bigger than zero
        vm.assume(rateERC1155ToToken1New <= uint256(type(int256).max));
        vm.assume(rateERC1155ToToken1New <= type(uint256).max / Constants.WAD);
        vm.assume(rateERC1155ToToken1New > 0);

        vm.assume(
            amountERC1155
                > type(uint256).max / Constants.WAD * 10 ** Constants.erc1155OracleDecimals
                    / uint256(rateERC1155ToToken1New)
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.erc1155ToToken1.transmit(int256(rateERC1155ToToken1New));
        vm.stopPrank();

        IPricingModule_UsdOnly.GetValueInput memory getValueInput = IPricingModule_UsdOnly.GetValueInput({
            asset: address(mockERC1155.erc1155),
            assetId: 1,
            assetAmount: amountERC1155,
            baseCurrency: UsdBaseCurrencyID
        });
        // When: getValue called

        // Then: getValue should be reverted
        // The following could revert with arithmetic over/underflow from a multiplication in getValue()
        // or due to the error "Revert(0,0)" emitted in solmate library: FixedPointMathLib (accessed through OracleHub contract)
        vm.expectRevert();
        floorERC1155PricingModule.getValue(getValueInput);
    }
}
