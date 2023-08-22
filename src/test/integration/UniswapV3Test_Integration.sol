/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { UniswapV3Fixture, INonfungiblePositionManagerExtension } from "./fixtures/uniswap-v3/UniswapV3Fixture.f.sol";
import { IUniswapV3PoolExtension } from "../../test_old/interfaces/IUniswapV3PoolExtension.sol";
import {
    UniswapV3WithFeesPricingModule,
    PricingModule,
    IPricingModule,
    TickMath,
    LiquidityAmounts,
    FixedPointMathLib
} from "../../PricingModules/UniswapV3/UniswapV3WithFeesPricingModule.sol";
import { LiquidityAmountsExtension } from "../../test_old/libraries/LiquidityAmountsExtension.sol";

contract UniswapV3Test_Integration_Test is Base_IntegrationAndUnit_Test, UniswapV3Fixture {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test, UniswapV3Fixture) {
        Base_IntegrationAndUnit_Test.setUp();
        UniswapV3Fixture.setUp();
    }

    /*////////////////////////////////////////////////////////////////
                            HELPERS
    ////////////////////////////////////////////////////////////////*/

    function createPool(ERC20 token0, ERC20 token1, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension pool)
    {
        address poolAddress = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(token0), address(token1), 100, sqrtPriceX96
        ); // Set initial price to lowest possible price.
        pool = IUniswapV3PoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        (uint160 sqrtPrice,,,,,,) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        tokenId = addLiquidity(pool, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        // Check if test should revert or be skipped when liquidity is zero.
        // This is hard to check with assumes of the fuzzed inputs due to rounding errors.
        if (!revertsOnZeroLiquidity) {
            (uint160 sqrtPrice,,,,,,) = pool.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        address token0 = pool.token0();
        address token1 = pool.token1();
        uint24 fee = pool.fee();

        deal(token0, liquidityProvider_, amount0);
        deal(token1, liquidityProvider_, amount1);
        vm.startPrank(liquidityProvider_);
        ERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
        ERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
        (tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider_,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                              TEST
    /////////////////////////////////////////////////////////////// */

    function test_deployUniswapV3() public {
        IUniswapV3PoolExtension pool =
            createPool(mockERC20.token1, mockERC20.token2, TickMath.getSqrtRatioAtTick(0), 300);

        nonfungiblePositionManager.factory();

        uint256 tokenId = addLiquidity(pool, 1000, address(5), -60, 60, true);

        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
    }

    function test_bytesShit() public {
        //bytes32 target = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        //bytes32 replacement = 0xd955f5f083633b64c9162f664c8ca6401a865e12ef1d9d88c67f5b571e6e99de;
        bytes32 bytecode_ = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytes32 target_ = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        //bytes32 target_ = 0x4f19000000000000000000000000000000000000000000000000000000000000;
        bytes32 replacement_ = 0x55f500000000000000000000000000000000000000000000000900000000000f;

        bytes memory bytecode = abi.encodePacked(bytecode_);
        bytes memory target = abi.encodePacked(target_);
        bytes memory replacement = abi.encodePacked(replacement_);
        emit log_named_bytes("bytecode", bytecode);
        emit log_named_bytes("target", target);
        emit log_named_bytes("replacement", replacement);

        bytes memory result;

        uint256 lengthTarget = target.length;
        uint256 lengthBytecode = bytecode.length - lengthTarget + 1;
        uint256 i;
        for (i; i < lengthBytecode;) {
            uint256 j = 0;
            for (j; j < lengthTarget;) {
                if (bytecode[i + j] == target[j]) {
                    emit log_named_uint('i+j', i+j);
                    emit log_named_uint('j', j);
                    emit log_named_bytes32('bytecode[i+j]', bytecode[i + j]);
                    emit log_named_bytes32('target[j]', target[j]);
                    if (j == lengthTarget - 1) {
                        result = replace(bytecode, replacement, i);
                        i = lengthBytecode - 1; // Break outer loop
                        emit log_string('check');
                    }
                } else {
                    break;
                }
                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        emit log_named_bytes("result", result);
    }
}
