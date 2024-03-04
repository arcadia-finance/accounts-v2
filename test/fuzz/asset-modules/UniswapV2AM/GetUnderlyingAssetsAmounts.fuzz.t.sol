/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { Constants } from "../../../utils/Constants.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts()" of contract "UniswapV2AM".
 */
contract GetUnderlyingAssetsAmounts_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        uniswapV2AM.addAsset(address(pairToken1Token2));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    // Note: Only tests for balanced pools, other tests in "GetTrustedReserves.fuzz.t.sol" show that "_getTrustedReserves" brings unbalanced pool into balance.

    function testFuzz_Success_getUnderlyingAssetsAmounts(
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 assetAmount
    ) public {
        // Given: reserves are not 0 (division by 0) and smaller or equal as uint122.max (type in Uniswap V2).
        reserve0 = bound(reserve0, 1, type(uint112).max);
        reserve1 = bound(reserve1, 1, type(uint112).max);

        // And: "token0ToToken1" in "_computeProfitMaximizingTrade" does not overflow (unreasonable value + reserve for same token).
        reserve0 = bound(reserve0, 1, type(uint256).max / (reserve1 * 10 ** (18 - Constants.tokenOracleDecimals)));

        // And: "totalSupply" is bigger than0 (division by 0).
        totalSupply = bound(totalSupply, 1, type(uint256).max);

        // And: "assetAmount" is smaller or equal as "totalSupply" (invariant ERC20).
        assetAmount = bound(assetAmount, 0, totalSupply);

        // And: "token0Amount" and "token1Amount" in _computeTokenAmounts() do not overflow.
        assetAmount = bound(assetAmount, 0, type(uint256).max / reserve0);
        assetAmount = bound(assetAmount, 0, type(uint256).max / reserve1);

        // And state is persisted/
        pairToken1Token2.setReserves(reserve0, reserve1);
        stdstore.target(address(pairToken1Token2)).sig(pairToken1Token2.totalSupply.selector).checked_write(totalSupply);

        // And the pool is balanced.
        uint256 priceToken0 = reserve1;
        uint256 priceToken1 = reserve0;
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(priceToken1));
        mockOracles.token2ToUsd.transmit(int256(priceToken0));
        vm.stopPrank();

        // When: "getUnderlyingAssetsAmounts" is called.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pairToken1Token2)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            uniswapV2AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, assetAmount, underlyingAssetKeys);

        // Then: The correct "underlyingAssetsAmounts" rates are returned.
        uint256 expectedUnderlyingAssetsAmount0 = assetAmount * reserve0 / totalSupply;
        uint256 expectedUnderlyingAssetsAmount1 = assetAmount * reserve1 / totalSupply;
        assertEq(underlyingAssetsAmounts[0], expectedUnderlyingAssetsAmount0);
        assertEq(underlyingAssetsAmounts[1], expectedUnderlyingAssetsAmount1);

        // And: The correct "rateUnderlyingAssetsToUsd" are returned.
        uint256 expectedRateUnderlyingAssetsToUsd0 = priceToken0 * 10 ** (18 - Constants.tokenOracleDecimals);
        uint256 expectedRateUnderlyingAssetsToUsd1 = priceToken1 * 10 ** (18 - Constants.tokenOracleDecimals);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, expectedRateUnderlyingAssetsToUsd0);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, expectedRateUnderlyingAssetsToUsd1);
    }
}
