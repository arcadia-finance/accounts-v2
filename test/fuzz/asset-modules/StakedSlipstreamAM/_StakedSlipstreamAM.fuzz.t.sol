/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { ICLGauge } from "../../../../src/asset-modules/Slipstream/interfaces/ICLGauge.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { LiquidityAmountsExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { SlipstreamFixture } from "../../../utils/fixtures/slipstream/Slipstream.f.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAMExtension } from "../../../utils/extensions/StakedSlipstreamAMExtension.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Common logic needed by all "StakedSlipstreamAM" fuzz tests.
 */
abstract contract StakedSlipstreamAM_Fuzz_Test is Fuzz_Test, SlipstreamFixture {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC20Mock internal token0;
    ERC20Mock internal token1;
    ICLGauge internal gauge;
    ICLPoolExtension internal pool;

    struct TestVariables {
        uint256 decimals0;
        uint256 decimals1;
        int24 tickLower;
        int24 tickUpper;
        uint64 priceToken0;
        uint64 priceToken1;
        uint80 liquidity;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StakedSlipstreamAMExtension internal stakedSlipstreamAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, SlipstreamFixture) {
        Fuzz_Test.setUp();
        SlipstreamFixture.setUp();

        // Deploy fixture for Slipstream.
        deployAerodromePeriphery();
        deploySlipstream();

        // Deploy fixture for CLGaugeFactory.
        deployCLGaugeFactory();

        // Add the reward token to the Registry
        addAssetToArcadia(AERO, int256(rates.token1ToUsd));
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/
    function deployStakedSlipstreamAM() internal {
        // Deploy StakedSlipstreamAM.
        vm.startPrank(users.owner);
        stakedSlipstreamAM =
            new StakedSlipstreamAMExtension(address(registry), address(slipstreamPositionManager), address(voter), AERO);

        // Add the Asset Module to the Registry.
        registry.addAssetModule(address(stakedSlipstreamAM));
        stakedSlipstreamAM.initialize();
        vm.stopPrank();
    }

    function deployAndAddGauge(int24 tick) internal {
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        addAssetToArcadia(address(token0), 1e18);
        addAssetToArcadia(address(token1), 1e18);

        pool = createPoolCL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeCL(pool);

        vm.prank(users.owner);
        stakedSlipstreamAM.addGauge(address(gauge));
    }

    function givenValidPosition(StakedSlipstreamAM.PositionState memory position)
        internal
        view
        returns (StakedSlipstreamAM.PositionState memory)
    {
        int24 tickSpacing = pool.tickSpacing();
        return givenValidPosition(position, tickSpacing);
    }

    function givenValidPosition(StakedSlipstreamAM.PositionState memory position, int24 tickSpacing)
        internal
        pure
        returns (StakedSlipstreamAM.PositionState memory)
    {
        // Given: Ticks are within allowed ranges.
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK));

        uint256 maxLiquidityPerTick = tickSpacingToMaxLiquidityPerTick(tickSpacing);
        position.liquidity = uint128(bound(position.liquidity, 1, maxLiquidityPerTick));

        return position;
    }

    function getActualLiquidity(StakedSlipstreamAM.PositionState memory position)
        public
        view
        returns (uint256 liquidity)
    {
        (uint160 sqrtPrice,,,,,) = pool.slot0();
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
        liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
            sqrtPrice,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            amount0,
            amount1
        );
    }

    function addLiquidity(StakedSlipstreamAM.PositionState memory position) public returns (uint256 tokenId) {
        (tokenId,,) = addLiquidityCL(
            pool, position.liquidity, users.liquidityProvider, position.tickLower, position.tickUpper, false
        );
    }
}
