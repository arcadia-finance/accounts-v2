/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Fuzz_Test, Constants } from "./Fuzz.t.sol";
import { IPricingModule_UsdOnly } from "../../interfaces/IPricingModule_UsdOnly.sol";

contract StandardERC20PricingModule_Fuzz_Test is Fuzz_Test {
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

    function testFuzz_getValue(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // Given: rateToken1ToUsdNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD
        vm.assume(rateToken1ToUsdNew <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsdNew <= type(uint256).max / Constants.WAD);

        if (rateToken1ToUsdNew == 0) {
            vm.assume(uint256(amountToken1) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(amountToken1)
                    <= (type(uint256).max / uint256(rateToken1ToUsdNew) / Constants.WAD)
                        * 10 ** Constants.tokenOracleDecimals
            );
        }

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));
        vm.stopPrank();

        uint256 expectedValueInUsd = (
            ((Constants.WAD * rateToken1ToUsdNew) / 10 ** Constants.tokenOracleDecimals) * amountToken1
        ) / 10 ** Constants.tokenDecimals;

        IPricingModule_UsdOnly.GetValueInput memory getValueInput = IPricingModule_UsdOnly.GetValueInput({
            asset: address(mockERC20.token1),
            assetId: 0,
            assetAmount: amountToken1,
            baseCurrency: UsdBaseCurrencyID
        });
        // When: getValue called
        (uint256 actualValueInUsd,,) = erc20PricingModule.getValue(getValueInput);

        // Then: actualValueInUsd should be equal to expectedValueInUsd
        assertEq(actualValueInUsd, expectedValueInUsd);
    }

    function testRevert_Fuzz_getValue_Overflow(uint256 rateToken1ToUsdNew, uint256 amountToken1) public {
        // Given: rateToken1ToUsdNew is lower than equal to max int256 value and max uint256 value divided by Constants.WAD and bigger than zero
        vm.assume(rateToken1ToUsdNew <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsdNew <= type(uint256).max / Constants.WAD);
        vm.assume(rateToken1ToUsdNew > 0);

        vm.assume(
            uint256(amountToken1)
                > (type(uint256).max / uint256(rateToken1ToUsdNew) / Constants.WAD) * 10 ** Constants.tokenOracleDecimals
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsdNew));
        vm.stopPrank();

        IPricingModule_UsdOnly.GetValueInput memory getValueInput = IPricingModule_UsdOnly.GetValueInput({
            asset: address(mockERC20.token1),
            assetId: 0,
            assetAmount: amountToken1,
            baseCurrency: UsdBaseCurrencyID
        });
        // When: getValue called

        // Then: getValue should be reverted
        vm.expectRevert(bytes(""));
        erc20PricingModule.getValue(getValueInput);
    }
}
