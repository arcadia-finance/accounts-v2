/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { PoolKey } from "../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "DefaultUniswapV4AM".
 */
contract GetRiskFactors_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors(TestVariables memory vars) public {
        // Given : Valid ticks
        (vars.tickLower, vars.tickUpper) = givenValidTicks(vars.tickLower, vars.tickUpper);

        // And : Initialize Uniswap V4 pool (initial tick set to zero, no impact on testing here).
        int24 tickSpacing = 1;
        PoolKey memory stable1ToToken1PoolKey = initializePoolV4(
            address(mockERC20.stable1),
            address(mockERC20.token1),
            TickMath.getSqrtPriceAtTick(0),
            address(validHook),
            500,
            tickSpacing
        );

        // And : Liquidity is within allowed ranges.
        vars.liquidity =
            uint80(bound(vars.liquidity, 1e18 + 1, poolManager.getTickSpacingToMaxLiquidityPerTick(tickSpacing)));

        // And : Liquidity position is minted.
        uint256 tokenId = mintPositionV4(
            stable1ToToken1PoolKey,
            vars.tickLower,
            vars.tickUpper,
            vars.liquidity,
            type(uint128).max,
            type(uint128).max,
            users.owner
        );

        // And : Risk factor is set for creditorUsd to 10_000
        address creditor = address(creditorUsd);
        uint256 riskFactor = AssetValuationLib.ONE_4;
        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.setRiskParameters(creditor, type(uint112).max, uint16(riskFactor));

        uint16 expectedCollateralFactor;
        uint16 expectedLiquidationFactor;
        {
            address[] memory assets = new address[](2);
            assets[0] = address(mockERC20.stable1);
            assets[1] = address(mockERC20.token1);
            uint256[] memory assetIds = new uint256[](2);

            (uint16[] memory collateralFactors, uint16[] memory liquidationFactors) =
                v4HooksRegistry.getRiskFactors(creditor, assets, assetIds);

            // Keep the lowest risk factor of all underlying assets.
            expectedCollateralFactor = uint16(
                collateralFactors[0] < collateralFactors[1]
                    ? riskFactor.mulDivDown(collateralFactors[0], AssetValuationLib.ONE_4)
                    : riskFactor.mulDivDown(collateralFactors[1], AssetValuationLib.ONE_4)
            );
            expectedLiquidationFactor = uint16(
                liquidationFactors[0] < liquidationFactors[1]
                    ? riskFactor.mulDivDown(liquidationFactors[0], AssetValuationLib.ONE_4)
                    : riskFactor.mulDivDown(liquidationFactors[1], AssetValuationLib.ONE_4)
            );
        }

        // When : Calling getRiskfactors()
        (uint16 collateralFactor, uint16 liquidationFactor) =
            uniswapV4AM.getRiskFactors(address(creditorUsd), address(positionManagerV4), tokenId);

        // Then : It should return the correct values
        assertEq(collateralFactor, expectedCollateralFactor);
        assertEq(liquidationFactor, expectedLiquidationFactor);
        assertGt(collateralFactor, 0);
        assertGt(liquidationFactor, 0);
    }
}
