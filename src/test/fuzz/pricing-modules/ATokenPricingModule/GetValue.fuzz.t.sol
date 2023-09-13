/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, ATokenPricingModule_Fuzz_Test } from "./ATokenPricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../../lib/forge-std/src/Test.sol";

import { IPricingModule } from "../../../../interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "ATokenPricingModule".
 */
contract GetValue_ATokenPricingModule_Fuzz_Test is ATokenPricingModule_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ATokenPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_getValue_Overflow(uint256 rateToken1ToUsd_, uint256 amountToken1) public {
        vm.assume(rateToken1ToUsd_ <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);
        vm.assume(rateToken1ToUsd_ > 0);

        vm.assume(
            uint256(amountToken1)
                > type(uint256).max / Constants.WAD * 10 ** Constants.tokenOracleDecimals / uint256(rateToken1ToUsd_)
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));
        vm.stopPrank();

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(aToken1),
            assetId: 0,
            assetAmount: amountToken1,
            baseCurrency: UsdBaseCurrencyID
        });
        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        aTokenPricingModule.getValue(getValueInput);
    }

    function testSuccess_getValue(uint256 rateToken1ToUsd_, uint256 amountToken1) public {
        vm.assume(rateToken1ToUsd_ <= uint256(type(int256).max));
        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);

        if (rateToken1ToUsd_ == 0) {
            vm.assume(uint256(amountToken1) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(amountToken1)
                    <= type(uint256).max / Constants.WAD * 10 ** Constants.tokenOracleDecimals / uint256(rateToken1ToUsd_)
            );
        }

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));
        vm.stopPrank();

        uint256 expectedValueInUsd = (
            ((Constants.WAD * rateToken1ToUsd_) / 10 ** Constants.tokenOracleDecimals) * amountToken1
        ) / 10 ** Constants.tokenDecimals;

        emit log_named_uint("(Constants.WAD * rateToken1ToUsd_)", (Constants.WAD * rateToken1ToUsd_));
        emit log_named_uint("Constants.tokenOracleDecimals", Constants.tokenOracleDecimals);

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(aToken1),
            assetId: 0,
            assetAmount: amountToken1,
            baseCurrency: UsdBaseCurrencyID
        });
        (uint256 actualValueInUsd,,) = aTokenPricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
