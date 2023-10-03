/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, ATokenPricingModule_Fuzz_Test } from "./_ATokenPricingModule.fuzz.t.sol";
import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

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
    function testFuzz_Revert_getValue_Overflow(uint256 rateToken1ToUsd_, uint256 amountToken1) public {
        // No Overflow OracleHub
        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);
        vm.assume(rateToken1ToUsd_ > 0);

        vm.assume(
            uint256(amountToken1)
                > type(uint256).max / (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals)
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));

        vm.prank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput);

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

    function testFuzz_Success_getValue(uint256 rateToken1ToUsd_, uint256 amountToken1) public {
        // No Overflow OracleHub
        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);

        if (rateToken1ToUsd_ != 0) {
            vm.assume(
                uint256(amountToken1)
                    <= type(uint256).max / (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals)
            );
        }

        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));

        vm.prank(users.creatorAddress);
        aTokenPricingModule.addAsset(address(aToken1), emptyRiskVarInput);

        uint256 expectedValueInUsd = (
            (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals) * amountToken1
        ) / 10 ** Constants.tokenDecimals;

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
