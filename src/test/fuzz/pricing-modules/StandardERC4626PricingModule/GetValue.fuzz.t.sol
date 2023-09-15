/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../../lib/forge-std/src/Test.sol";

import { IPricingModule } from "../../../../interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "StandardERC4626PricingModule".
 */
contract GetValue_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_getValue_Overflow(
        uint256 rateToken1ToUsd_,
        uint256 shares,
        uint256 totalSupply,
        uint256 totalAssets
    ) public {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);
        vm.assume(totalAssets > 0);
        vm.assume(rateToken1ToUsd_ > 0);

        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);
        vm.assume(shares <= type(uint256).max / totalAssets);

        vm.assume(
            shares * totalAssets / totalSupply
                > type(uint256).max / Constants.WAD * 10 ** Constants.tokenOracleDecimals / uint256(rateToken1ToUsd_)
        );

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        erc4626PricingModule.addAsset(address(ybToken1), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);

        //Cheat balance of
        stdstore.target(address(mockERC20.token1)).sig(ybToken1.balanceOf.selector).with_key(address(ybToken1))
            .checked_write(totalAssets);

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(ybToken1),
            assetId: 0,
            assetAmount: shares,
            baseCurrency: UsdBaseCurrencyID
        });

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        erc4626PricingModule.getValue(getValueInput);
    }

    function testSuccess_getValue(uint256 rateToken1ToUsd_, uint256 shares, uint256 totalSupply, uint256 totalAssets)
        public
    {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);

        vm.assume(rateToken1ToUsd_ <= type(uint256).max / Constants.WAD);
        if (totalAssets > 0) {
            vm.assume(shares <= type(uint256).max / totalAssets);
        }
        if (rateToken1ToUsd_ == 0) {
            vm.assume(shares * totalAssets / totalSupply <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                shares * totalAssets / totalSupply
                    <= type(uint256).max / Constants.WAD * 10 ** Constants.tokenOracleDecimals / uint256(rateToken1ToUsd_)
            );
        }

        uint256 expectedValueInUsd = (shares * totalAssets / totalSupply)
            * (Constants.WAD * rateToken1ToUsd_ / 10 ** Constants.tokenOracleDecimals) / 10 ** Constants.tokenDecimals;

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rateToken1ToUsd_));
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        erc4626PricingModule.addAsset(address(ybToken1), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        stdstore.target(address(ybToken1)).sig(ybToken1.totalSupply.selector).checked_write(totalSupply);

        //Cheat balance of
        stdstore.target(address(mockERC20.token1)).sig(ybToken1.balanceOf.selector).with_key(address(ybToken1))
            .checked_write(totalAssets);

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(ybToken1),
            assetId: 0,
            assetAmount: shares,
            baseCurrency: UsdBaseCurrencyID
        });
        (uint256 actualValueInUsd,,) = erc4626PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
