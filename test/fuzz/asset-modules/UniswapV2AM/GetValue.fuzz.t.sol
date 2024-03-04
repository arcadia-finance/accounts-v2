/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";
import { UniswapV2PairMock } from "../../../utils/mocks/UniswapV2/UniswapV2PairMock.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "UniswapV2AM".
 */
contract GetValue_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
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
            mockOracles.token1ToUsd, _token1Decimals, _oracleToken1ToUsdDecimals, _rateToken1ToUsd, "TOKEN1"
        );
        mockERC20.token2 =
            deployToken(oracleToken2ToUsd, _token2Decimals, _oracleToken2ToUsdDecimals, _rateToken2ToUsd, "TOKEN2");
        pairToken1Token2 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token2), address(mockERC20.token1)));
        uniswapV2AM.addAsset(address(pairToken1Token2));

        // Mint LP
        vm.assume(uint256(amountToken2) * amountToken1 > pairToken1Token2.MINIMUM_LIQUIDITY()); //min liquidity in uniswap pool
        pairToken1Token2.mint(users.tokenCreatorAddress, amountToken2, amountToken1);

        bool cond0 = uint256(_rateToken2ToUsd)
            > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleToken2ToUsdDecimals; // trustedPriceToken2ToUsd overflows
        bool cond1 = uint256(_rateToken1ToUsd)
            > type(uint256).max / Constants.WAD / Constants.WAD * 10 ** _oracleToken1ToUsdDecimals; // trustedPriceToken1ToUsd overflows
        vm.assume(cond0 || cond1);

        //Arithmetic overflow.
        uint256 amount = pairToken1Token2.totalSupply();
        vm.expectRevert(bytes(""));
        uniswapV2AM.getValue(address(creditorUsd), address(pairToken1Token2), 0, amount);
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
            mockOracles.token1ToUsd, _token1Decimals, _oracleToken1ToUsdDecimals, _rateToken1ToUsd, "TOKEN1"
        );
        mockERC20.token2 =
            deployToken(oracleToken2ToUsd, _token2Decimals, _oracleToken2ToUsdDecimals, _rateToken2ToUsd, "TOKEN2");
        pairToken1Token2 =
            UniswapV2PairMock(uniswapV2Factory.createPair(address(mockERC20.token2), address(mockERC20.token1)));
        uniswapV2AM.addAsset(address(pairToken1Token2));

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

        (uint256 actualValueInUsd,,) =
            uniswapV2AM.getValue(address(creditorUsd), address(pairToken1Token2), 0, pairToken1Token2.totalSupply());

        assertInRange(actualValueInUsd, expectedValueInUsd, 4);
    }
}
