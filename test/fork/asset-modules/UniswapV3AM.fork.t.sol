/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { Fork_Test } from "../Fork.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";

import { LiquidityAmounts } from "../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { LiquidityAmountsExtension } from
    "../../utils/fixtures/uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { INonfungiblePositionManagerExtension } from
    "../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { ISwapRouter } from "../../utils/fixtures/uniswap-v3/extensions/interfaces/ISwapRouter.sol";
import { IUniswapV3Factory } from "../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3PoolExtension } from
    "../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { TickMath } from "../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fork tests for "UniswapV3AM".
 */
contract UniswapV3AM_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/
    INonfungiblePositionManagerExtension internal constant NONFUNGIBLE_POSITION_MANAGER =
        INonfungiblePositionManagerExtension(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter internal constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Factory internal constant UNISWAP_V3_FACTORY =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Fork_Test.setUp();

        // Deploy uniV3AssetModule.
        //deployUniswapV3AM(address(NONFUNGIBLE_POSITION_MANAGER));

        // Set max exposure to uniswap V3.
        //vm.prank(users.riskManager);
        //registryExtension.setRiskParametersOfDerivedAM(
        //    address(uniV3AssetModule), address(0), type(uint112).max, 100
        //);
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/
    //ToDo: move to shared contract with "_UniswapV3AM.fuzz.t.sol"
    function isWithinAllowedRange(int24 tick) public pure returns (bool) {
        int24 MIN_TICK = -887_272;
        int24 MAX_TICK = -MIN_TICK;
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(MAX_TICK));
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
        ERC20(token0).approve(address(NONFUNGIBLE_POSITION_MANAGER), type(uint256).max);
        ERC20(token1).approve(address(NONFUNGIBLE_POSITION_MANAGER), type(uint256).max);
        (tokenId,,,) = NONFUNGIBLE_POSITION_MANAGER.mint(
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

    function assertInRange(uint256 actualValue, uint256 expectedValue, uint8 precision) internal {
        if (expectedValue == 0) {
            assertEq(actualValue, expectedValue);
        } else {
            vm.assume(expectedValue > 10 ** (2 * precision));
            assertGe(actualValue * (10 ** precision + 1) / 10 ** precision, expectedValue);
            assertLe(actualValue * (10 ** precision - 1) / 10 ** precision, expectedValue);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/
    // ToDO: use actual addresses and oracles etc from deployscript.
    function testFork_Success_deposit(uint128 liquidity, int24 tickLower, int24 tickUpper) private {
        vm.assume(liquidity > 10_000);

        IUniswapV3PoolExtension pool =
            IUniswapV3PoolExtension(UNISWAP_V3_FACTORY.getPool(address(USDC), address(WETH), 100));
        (, int24 tickCurrent,,,,,) = pool.slot0();

        // Check that ticks are within allowed ranges.
        tickLower = int24(bound(tickLower, tickCurrent - 16_095, tickCurrent + 16_095));
        tickUpper = int24(bound(tickUpper, tickCurrent - 16_095, tickCurrent + 16_095));
        // Ensure Tick is correctly spaced.
        {
            int24 tickSpacing = UNISWAP_V3_FACTORY.feeAmountTickSpacing(pool.fee());
            tickLower = tickLower / tickSpacing * tickSpacing;
            tickUpper = tickUpper / tickSpacing * tickSpacing;
        }
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Balance pool before mint
        uint256 amountUsdcBefore = USDC.balanceOf(address(pool));
        uint256 amountWethBefore = WETH.balanceOf(address(pool));

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.creatorAddress, tickLower, tickUpper, false);

        // Balance pool after mint
        uint256 amountUsdcAfter = USDC.balanceOf(address(pool));
        uint256 amountWethAfter = WETH.balanceOf(address(pool));

        // Amounts deposited in the pool.
        uint256 amountUsdc = amountUsdcAfter - amountUsdcBefore;
        uint256 amountWeth = amountWethAfter - amountWethBefore;

        // Precision oracles up to % -> need to deposit at least 1000 tokens or rounding errors lead to bigger errors.
        vm.assume(amountUsdc + amountWeth > 100);

        // Deposit the Liquidity Position.
        {
            address[] memory assetAddress = new address[](1);
            assetAddress[0] = address(NONFUNGIBLE_POSITION_MANAGER);

            uint256[] memory assetId = new uint256[](1);
            assetId[0] = tokenId;

            uint256[] memory assetAmount = new uint256[](1);
            assetAmount[0] = 1;
            vm.startPrank(users.creatorAddress);
            ERC721(address(NONFUNGIBLE_POSITION_MANAGER)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assetAddress, assetId, assetAmount);
            vm.stopPrank();
        }

        uint256 actualValue = proxyAccount.getAccountValue(address(0));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(USDC);
        assetAddresses[1] = address(WETH);

        uint256[] memory assetIds = new uint256[](2);

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountUsdc;
        assetAmounts[1] = amountWeth;

        uint256 expectedValue =
            registryExtension.getTotalValue(address(0), address(0), assetAddresses, assetIds, assetAmounts);

        // Precision Chainlink oracles is often in the order of percentages.
        assertInRange(actualValue, expectedValue, 2);
    }
}
