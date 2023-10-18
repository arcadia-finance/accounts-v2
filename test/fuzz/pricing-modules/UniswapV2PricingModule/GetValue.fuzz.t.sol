/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";
import { UniswapV2PairMock } from "../../../utils/mocks/UniswapV2PairMock.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "UniswapV2PricingModule".
 */
contract GetValue_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValue_Overflow(
        uint112 amountToken2,
        uint112 amountToken1,
        uint8 _token1Decimals,
        uint8 _token2Decimals,
        uint8 _oracleToken1ToUsdDecimals,
        uint8 _oracleToken2ToUsdDecimals,
        uint144 _rateToken1ToUsd,
        uint144 _rateToken2ToUsd
    ) public {
        vm.assume(_token1Decimals <= 18);
        vm.assume(_token2Decimals <= 18);
        vm.assume(_oracleToken1ToUsdDecimals <= 18);
        vm.assume(_oracleToken2ToUsdDecimals <= 18);
        vm.assume(_rateToken1ToUsd > 0);
        vm.assume(_rateToken2ToUsd > 0);
        vm.assume(_rateToken1ToUsd <= uint256(type(int256).max));
        vm.assume(_rateToken2ToUsd <= uint256(type(int256).max));

        // Redeploy tokens with variable amount of decimals
        mockERC20.token1 = deployToken(
            mockOracles.token1ToUsd,
            _token1Decimals,
            _oracleToken1ToUsdDecimals,
            _rateToken1ToUsd,
            "TOKEN1",
            oracleToken1ToUsdArr
        );
        mockERC20.token2 = deployToken(
            oracleToken2ToUsd,
            _token2Decimals,
            _oracleToken2ToUsdDecimals,
            _rateToken2ToUsd,
            "TOKEN2",
            oracleToken2ToUsdArr
        );
        pairToken1Token2 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token2), address(mockERC20.token1)));
        uniswapV2PricingModule.addPool(address(pairToken1Token2));

        // Mint LP
        vm.assume(uint256(amountToken2) * amountToken1 > pairToken1Token2.MINIMUM_LIQUIDITY()); //min liquidity in uniswap pool
        pairToken1Token2.mint(users.tokenCreatorAddress, amountToken2, amountToken1);

        bool cond0 = uint256(_rateToken2ToUsd)
            > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleToken2ToUsdDecimals; // trustedPriceToken2ToUsd overflows
        bool cond1 = uint256(_rateToken1ToUsd)
            > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleToken1ToUsdDecimals; // trustedPriceToken1ToUsd overflows
        vm.assume(cond0 || cond1);

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(pairToken1Token2),
            assetId: 0,
            assetAmount: pairToken1Token2.totalSupply(),
            baseCurrency: UsdBaseCurrencyID
        });

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        uniswapV2PricingModule.getValue(getValueInput);
    }

    function testFuzz_Success_getValue(
        uint112 amountToken2,
        uint8 _token1Decimals,
        uint8 _token2Decimals,
        uint8 _oracleToken1ToUsdDecimals,
        uint8 _oracleToken2ToUsdDecimals,
        uint144 _rateToken1ToUsd,
        uint144 _rateToken2ToUsd
    ) public {
        vm.assume(_token1Decimals <= 18);
        vm.assume(_token2Decimals <= 18);
        vm.assume(_oracleToken1ToUsdDecimals <= 18);
        vm.assume(_oracleToken2ToUsdDecimals <= 18);
        vm.assume(_rateToken1ToUsd > 0);
        vm.assume(_rateToken2ToUsd > 0);

        // Redeploy tokens with variable amount of decimals
        mockERC20.token1 = deployToken(
            mockOracles.token1ToUsd,
            _token1Decimals,
            _oracleToken1ToUsdDecimals,
            _rateToken1ToUsd,
            "TOKEN1",
            oracleToken1ToUsdArr
        );
        mockERC20.token2 = deployToken(
            oracleToken2ToUsd,
            _token2Decimals,
            _oracleToken2ToUsdDecimals,
            _rateToken2ToUsd,
            "TOKEN2",
            oracleToken2ToUsdArr
        );
        pairToken1Token2 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token2), address(mockERC20.token1)));
        uniswapV2PricingModule.addPool(address(pairToken1Token2));

        // Mint a variable amount of balanced LP, for a given amountToken2
        vm.assume(
            uint256(amountToken2) * uint256(_rateToken2ToUsd)
                < type(uint256).max / 10 ** (_token1Decimals + _oracleToken1ToUsdDecimals)
        ); //Avoid overflow of amountToken1 in next line
        uint256 amountToken1 = uint256(amountToken2) * uint256(_rateToken2ToUsd)
            * 10 ** (_token1Decimals + _oracleToken1ToUsdDecimals) / _rateToken1ToUsd
            / 10 ** (_token2Decimals + _oracleToken2ToUsdDecimals);
        vm.assume(amountToken1 < type(uint112).max); //max reserve in Uniswap pool
        vm.assume(amountToken2 * amountToken1 > pairToken1Token2.MINIMUM_LIQUIDITY()); //min liquidity in uniswap pool
        pairToken1Token2.mint(users.tokenCreatorAddress, amountToken2, amountToken1);

        //No overflows
        vm.assume(
            uint256(_rateToken2ToUsd)
                <= type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleToken2ToUsdDecimals
        ); // trustedPriceToken2ToUsd does not overflow
        uint256 trustedPriceToken2ToUsd = Constants.WAD * uint256(_rateToken2ToUsd) / 10 ** _oracleToken2ToUsdDecimals
            * Constants.WAD / 10 ** _token2Decimals;
        vm.assume(
            uint256(_rateToken1ToUsd)
                <= type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleToken1ToUsdDecimals
        ); // trustedPriceToken1ToUsd does not overflow
        uint256 trustedPriceToken1ToUsd = Constants.WAD * uint256(_rateToken1ToUsd) / 10 ** _oracleToken1ToUsdDecimals
            * Constants.WAD / 10 ** _token1Decimals;
        vm.assume(trustedPriceToken2ToUsd <= type(uint256).max / amountToken2); // _computeProfitMaximizingTrade does not overflow
        vm.assume(trustedPriceToken1ToUsd <= type(uint256).max / 997); // _computeProfitMaximizingTrade does not overflow

        uint256 valueToken2 =
            Constants.WAD * _rateToken2ToUsd / 10 ** _oracleToken2ToUsdDecimals * amountToken2 / 10 ** _token2Decimals;
        uint256 valueToken1 =
            Constants.WAD * _rateToken1ToUsd / 10 ** _oracleToken1ToUsdDecimals * amountToken1 / 10 ** _token1Decimals;
        uint256 expectedValueInUsd = valueToken2 + valueToken1;

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(pairToken1Token2),
            assetId: 0,
            assetAmount: pairToken1Token2.totalSupply(),
            baseCurrency: UsdBaseCurrencyID
        });
        (uint256 actualValueInUsd,,) = uniswapV2PricingModule.getValue(getValueInput);

        assertInRange(actualValueInUsd, expectedValueInUsd, 4);
    }
}
