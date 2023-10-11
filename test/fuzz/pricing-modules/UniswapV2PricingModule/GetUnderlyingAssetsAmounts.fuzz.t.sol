/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./_UniswapV2PricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "_getUnderlyingAssetsAmounts()" of contract "UniswapV2PricingModule".
 */
contract GetUnderlyingAssetsAmounts_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        uniswapV2PricingModule.addAsset(address(pairToken1Token2), emptyRiskVarInput);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    // Note: Only tests for balanced pools, other tests in "GetTrustedReserves.fuzz.t.sol" show that "_getTrustedReserves" brings unbalanced pool into balance.

    function testFuzz_Success_getUnderlyingAssetsAmounts(uint256 reserve1, uint256 reserve2, uint256 totalSupply)
        public
    {
        // Given: reserves are not 0 (division by 0) and smaller or equal as uint122.max (type in Uniswap V2).
        reserve1 = bound(reserve1, 1, type(uint112).max);
        reserve2 = bound(reserve2, 1, type(uint112).max);

        // And: "token0ToToken1" does not overflow (unreasonable value + reserve for same token).
        reserve2 = bound(reserve2, 1, type(uint256).max / (reserve1 * 10 ** (18 - Constants.tokenOracleDecimals)));

        // And: "totalSupply" is bigger as 0 (division by 0).
        totalSupply = bound(totalSupply, 1, type(uint256).max);

        address[] memory underlyingTokens = uniswapV2PricingModule.getUnderlyingAssets(address(pairToken1Token2));
        assertEq(underlyingTokens[0], address(mockERC20.token2));
        assertEq(underlyingTokens[1], address(mockERC20.token1));

        // Given: The reserves in the pool are reserve1 and reserve2
        pairToken1Token2.setReserves(reserve2, reserve1);

        // And: The total supply of liquidity tokens is "totalSupply".
        stdstore.target(address(pairToken1Token2)).sig(pairToken1Token2.totalSupply.selector).checked_write(totalSupply);

        // And the pool is balanced.
        uint256 priceToken1 = reserve2;
        uint256 priceToken2 = reserve1;
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(priceToken1));
        mockOracles.token2ToUsd.transmit(int256(priceToken2));
        vm.stopPrank();

        // When: "getConversionRate" is called.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pairToken1Token2)));
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), underlyingTokens[0]));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), underlyingTokens[1]));
        (uint256[] memory exposureAssetToUnderlyingAssets) =
            uniswapV2PricingModule.getUnderlyingAssetsAmounts(assetKey, 1e18, underlyingAssetKeys);

        // Then: The correct conversion rates are returned.
        uint256 conversionRateToken1Expected = 1e18 * reserve1 / totalSupply;
        uint256 conversionRateToken2Expected = 1e18 * reserve2 / totalSupply;
        assertEq(conversionRateToken2Expected, exposureAssetToUnderlyingAssets[0]);
        assertEq(conversionRateToken1Expected, exposureAssetToUnderlyingAssets[1]);
    }
}
