/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { NonfungiblePositionManagerMock } from "../../../utils/mocks/NonfungiblePositionManager.sol";

/**
 * @notice Fuzz tests for the "_getPosition" of contract "UniswapV3PricingModule".
 */
contract GetPosition_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint256 internal assetId;
    address token0;
    address token1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();

        assetId = addLiquidity(poolStable1Stable2, 100, 100, users.liquidityProvider, 0, 1, true);
        (token0, token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        deployUniswapV3PricingModule(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InPricingModule(
        NonfungiblePositionManagerMock.Position memory position,
        uint128 newLiquidity
    ) public {
        // Given: Position is valid.
        position = givenValidPosition(position);

        // And: Liquidity is non-zero.
        position.liquidity = uint128(bound(position.liquidity, 1, type(uint128).max));

        // And: State is persisted.
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // And: The Uniswap V3 position is added to the pricing Module.
        uniV3PricingModule.addAsset(assetId);

        // And: The Liquidity of the position changes
        uint256 oldLiquidity = position.liquidity;
        position.liquidity = newLiquidity;
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // When: "getPosition is called."
        (address token0_, address token1_, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            uniV3PricingModule.getPosition(assetId);

        // Then: The correct return variables are returned.
        assertEq(token0_, token0);
        assertEq(token1_, token1);
        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);

        // And: the Liquidity when the position was added is returned.
        assertEq(liquidity, oldLiquidity);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInPricingModule(
        NonfungiblePositionManagerMock.Position memory position,
        uint128 newLiquidity
    ) public {
        // Given: Position is valid.
        position = givenValidPosition(position);

        // And: State is persisted.
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);

        // When: "getPosition is called."
        (address token0_, address token1_, int24 tickLower, int24 tickUpper, uint128 liquidity) =
            uniV3PricingModule.getPosition(assetId);

        // Then: The correct return variables are returned.
        assertEq(token0_, token0);
        assertEq(token1_, token1);
        assertEq(tickLower, position.tickLower);
        assertEq(tickUpper, position.tickUpper);
        assertEq(liquidity, position.liquidity);

        // And: The actual Liquidity is returned.
        position.liquidity = newLiquidity;
        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), assetId, position);
        (,,,, liquidity) = uniV3PricingModule.getPosition(assetId);
        assertEq(liquidity, newLiquidity);
    }
}
