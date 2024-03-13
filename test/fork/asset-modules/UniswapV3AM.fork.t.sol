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
import { UniswapV3AM } from "../../../src/asset-modules/UniswapV3/UniswapV3AM.sol";

/**
 * @notice Fork tests for "UniswapV3AM".
 */
contract UniswapV3AM_Fork_Test is Fork_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/
    INonfungiblePositionManagerExtension internal constant NONFUNGIBLE_POSITION_MANAGER =
        INonfungiblePositionManagerExtension(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    ISwapRouter internal constant SWAP_ROUTER = ISwapRouter(0x2626664c2603336E57B271c5C0b26F421741e481);
    IUniswapV3Factory internal constant UNISWAP_V3_FACTORY =
        IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);

    int24 MIN_TICK = -887_272;
    int24 MAX_TICK = -MIN_TICK;

    /*///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    ///////////////////////////////////////////////////////////////*/

    UniswapV3AM internal uniV3AM_;
    IUniswapV3PoolExtension internal pool;

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        Fork_Test.setUp();

        // Deploy uniV3AM_.
        vm.startPrank(users.creatorAddress);
        uniV3AM_ = new UniswapV3AM(address(registryExtension), address(NONFUNGIBLE_POSITION_MANAGER));
        registryExtension.addAssetModule(address(uniV3AM_));
        uniV3AM_.setProtocol();
        vm.stopPrank();

        pool = IUniswapV3PoolExtension(UNISWAP_V3_FACTORY.getPool(address(DAI), address(WETH), 100));

        vm.label({ account: address(uniV3AM_), newLabel: "Uniswap V3 Asset Module" });
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/
    function givenTickWithinAllowedRange(int24 tick) public view returns (int24) {
        uint256 tick_;
        if (tick < 0) {
            tick_ = uint256(-int256(tick));
            tick_ = bound(tick_, 0, uint256(-int256(MIN_TICK)));
            return -int24(uint24(tick_));
        } else {
            tick_ = uint256(int256(tick));
            tick_ = bound(tick_, 0, uint256(int256(MAX_TICK)));
            return int24(uint24(tick_));
        }
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool_,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        (uint160 sqrtPrice,,,,,,) = pool_.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        tokenId =
            addLiquidity(pool_, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool_,
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
            (uint160 sqrtPrice,,,,,,) = pool_.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        address token0 = pool_.token0();
        address token1 = pool_.token1();
        uint24 fee = pool_.fee();

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

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/
    // ToDO: use actual addresses and oracles etc from deployscript.
    function testFork_Success_deposit(uint128 liquidity, int24 tickLower, int24 tickUpper) public {
        vm.skip(true);
        // Given: Liquidity is within allowed ranges.
        liquidity = uint128(bound(liquidity, 10_000, pool.maxLiquidityPerTick()));

        // And: Ticks are within allowed ranges.
        tickLower = givenTickWithinAllowedRange(tickLower);
        tickUpper = givenTickWithinAllowedRange(tickUpper);
        // And: Ticks are correctly spaced.
        {
            int24 tickSpacing = UNISWAP_V3_FACTORY.feeAmountTickSpacing(pool.fee());
            tickLower = tickLower / tickSpacing * tickSpacing;
            tickUpper = tickUpper / tickSpacing * tickSpacing;
        }
        vm.assume(tickLower != tickUpper);
        (tickLower, tickUpper) = tickLower < tickUpper ? (tickLower, tickUpper) : (tickUpper, tickLower);

        // Precision oracles up to % -> need to deposit at least 1000 tokens or rounding errors lead to bigger errors.
        (uint160 sqrtPrice,,,,,,) = pool.slot0();
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
        vm.assume(amount0 > 1e3 && amount1 == 0 || amount0 == 0 && amount1 > 1e3 || amount0 > 1e3 && amount1 > 1e3);

        // Balance pool before mint
        uint256 amountDaiBefore = DAI.balanceOf(address(pool));
        uint256 amountWethBefore = WETH.balanceOf(address(pool));

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.accountOwner, tickLower, tickUpper, false);

        // Balance pool after mint
        uint256 amountDaiAfter = DAI.balanceOf(address(pool));
        uint256 amountWethAfter = WETH.balanceOf(address(pool));

        // Amounts deposited in the pool.
        uint256 amountDai = amountDaiAfter - amountDaiBefore;
        uint256 amountWeth = amountWethAfter - amountWethBefore;

        // Deposit the Liquidity Position.
        {
            address[] memory assetAddress = new address[](1);
            assetAddress[0] = address(NONFUNGIBLE_POSITION_MANAGER);

            uint256[] memory assetId = new uint256[](1);
            assetId[0] = tokenId;

            uint256[] memory assetAmount = new uint256[](1);
            assetAmount[0] = 1;
            vm.startPrank(users.accountOwner);
            ERC721(address(NONFUNGIBLE_POSITION_MANAGER)).approve(address(proxyAccount), tokenId);
            proxyAccount.deposit(assetAddress, assetId, assetAmount);
            vm.stopPrank();
        }

        uint256 actualValue = proxyAccount.getAccountValue(address(0));

        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(DAI);
        assetAddresses[1] = address(WETH);

        uint256[] memory assetIds = new uint256[](2);

        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = amountDai;
        assetAmounts[1] = amountWeth;

        uint256 expectedValue =
            registryExtension.getTotalValue(address(0), address(0), assetAddresses, assetIds, assetAmounts);

        // Precision Chainlink oracles is often in the order of percentages.
        assertApproxEqRel(actualValue, expectedValue, 1e16);
    }
}
