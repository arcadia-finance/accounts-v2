/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the "_getConversionRate()" of contract "UniswapV2PricingModule".
 */
contract GetConversionRate_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getConversionRateToken0(
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount
    ) public {
        // Only test for balanced pool, other tests guarantee that _getTrustedReserves brings unbalanced pool into balance
        vm.assume(liquidityAmount > 0); // division by 0
        vm.assume(reserve0 > 0); // division by 0
        vm.assume(reserve1 > 0); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(liquidityAmount <= type(uint256).max / reserve0); // overflow, unrealistic big liquidityAmount
        vm.assume(liquidityAmount <= type(uint256).max / reserve1); // overflow, unrealistic big liquidityAmount

        (,, address[] memory underlyingTokens,) = uniswapV2PricingModule.getAssetInformation(address(pairToken1Token2));
        assertEq(underlyingTokens[0], address(mockERC20.token2));
        assertEq(underlyingTokens[1], address(mockERC20.token1));

        // Given: The reserves in the pool are reserve0 and reserve1
        pairToken1Token2.setReserves(reserve0, reserve1);

        stdstore.target(address(pairToken1Token2)).sig(pairToken1Token2.totalSupply.selector).checked_write(totalSupply);

        /*         uint256 trustedPriceToken0 = PricingModule(token1PricingModule).getValue(
            IPricingModule.GetValueInput({ asset: underlyingTokens[1], assetId: 0, assetAmount: 1e18, baseCurrency: 0 })
        );
        uint256 trustedPriceToken1 = PricingModule(token1PricingModule).getValue(
            IPricingModule.GetValueInput({ asset: underlyingTokens[1], assetId: 0, assetAmount: 1e18, baseCurrency: 0 })
        ); */

        /*         (uint256 token0AmountActual, uint256 token1AmountActual) = uniswapV2PricingModule.getTrustedTokenAmounts(
            address(pairToken1Token2), trustedPriceToken0, trustedPriceToken1, 1e18
        );

        assertEq(token0AmountActual, token0AmountExpected);
        assertEq(token1AmountActual, token1AmountExpected); */

        // We have to add the asset in order to have info available in pricing module
        /*         vm.prank(users.creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), emptyRiskVarInput);

        uint256 token0ConversionRate = uniswapV2PricingModule.getConversionRate(address(pairToken1Token2), address(mockERC20.token2));

        assertEq(token0ConversionRate, token0AmountActual); */
    }

    function testFuzz_Success_getConversionRateToken1(address unprivilegedAddress_) public { }
}
