/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FixedPoint96 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint96.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { ICLSwapRouter } from "../../../utils/fixtures/slipstream/interfaces/ICLSwapRouter.sol";
import { IMetadex03CLGauge } from "../../../../src/asset-modules/Metadex03/interfaces/IMetadex03CLGauge.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import {
    LiquidityAmountsExtension
} from "../../../utils/fixtures/uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { Metadex03CLFixture } from "../../../utils/fixtures/metadex03/Metadex03CL.f.sol";
import { Metadex03CLSwapRouterFixture } from "../../../utils/fixtures/metadex03/Metadex03CLSwapRouter.f.sol";
import { StakedMetadex03CLAMExtension } from "../../../utils/extensions/StakedMetadex03CLAMExtension.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Common logic needed by all "StakedMetadex03CLAM" fuzz tests.
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
abstract contract StakedMetadex03CLAM_Fuzz_Test is Fuzz_Test, Metadex03CLFixture, Metadex03CLSwapRouterFixture {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    // The hard cap a swap hook's fee is clamped to, and the pips denominator it is expressed in.
    uint24 internal constant SWAP_FEE_CEIL = 100_000;
    uint256 internal constant SWAP_FEE_DENOMINATOR = 1e6;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC20Mock internal token0;
    ERC20Mock internal token1;
    IMetadex03CLGauge internal gauge;
    ICLPoolExtension internal pool;
    address internal surplusRecipient;

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

    // forge-lint: disable-next-line(mixed-case-variable)
    StakedMetadex03CLAMExtension internal stakedMetadex03CLAM;

    // The token the chain's emissions handler delivers.
    address internal rewardToken;

    // Bool indicating if the staged chain is the root chain.
    bool internal isRoot;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, Metadex03CLFixture) {
        Fuzz_Test.setUp();
        Metadex03CLFixture.setUp();

        surplusRecipient = users.treasury;
        deployMetadex03Periphery(false);
        deployMetadex03CL();
        _stageMetadex03CL(false);
    }

    // forge-lint: disable-next-item(mixed-case-function)
    function _stageMetadex03CL(bool root) internal {
        isRoot = root;

        if (root) deployMetadex03CLOnRoot();
        deployMetadex03CLGaugeFactory();

        rewardToken = root ? rootToken : receiptToken;
        // forge-lint: disable-next-item(unsafe-typecast)
        addAssetToArcadia(rewardToken, int256(rates.token1ToUsd));
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    // forge-lint: disable-next-item(mixed-case-function)
    function deployStakedMetadex03CLAM() internal {
        // Deploy StakedMetadex03CLAM.
        vm.startPrank(users.owner);
        stakedMetadex03CLAM = new StakedMetadex03CLAMExtension(
            users.owner, address(registry), address(metadex03CLGaugeFactory), rewardToken, surplusRecipient
        );

        // Add the Asset Module to the Registry.
        registry.addAssetModule(address(stakedMetadex03CLAM));
        stakedMetadex03CLAM.initialize();
        vm.stopPrank();
    }

    // Excludes the addresses whose Reward Token balance a sweep assertion reads.
    function _givenValidRecipient(address recipient) internal view {
        vm.assume(recipient != address(0));
        vm.assume(recipient.code.length == 0);
        vm.assume(recipient != users.accountOwner);
        vm.assume(recipient != users.liquidityProvider);
    }

    function _givenSurplusRecipient(address recipient) internal {
        _givenValidRecipient(recipient);

        surplusRecipient = recipient;
        vm.prank(users.owner);
        stakedMetadex03CLAM.setSurplusRecipient(recipient);
    }

    function deployAndAddGauge(int24 tick) internal {
        deployAndAddGauge(tick, true);
    }

    function deployAndAddGauge(int24 tick, bool activate) internal {
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
        (token0, token1) = address(tokenA) < address(tokenB) ? (tokenA, tokenB) : (tokenB, tokenA);
        addAssetToArcadia(address(token0), 1e18);
        addAssetToArcadia(address(token1), 1e18);

        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool, activate);

        vm.prank(users.owner);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function deployAndAddGaugeWithRewardToken(int24 tick) internal {
        ERC20Mock other = new ERC20Mock("Token A", "TOKENA", 18);
        addAssetToArcadia(address(other), 1e18);
        (token0, token1) =
            rewardToken < address(other) ? (ERC20Mock(rewardToken), other) : (other, ERC20Mock(rewardToken));

        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool, true);

        vm.prank(users.owner);
        stakedMetadex03CLAM.addGauge(address(gauge));
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
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK));

        uint256 maxLiquidityPerTick = tickSpacingToMaxLiquidityPerTick(tickSpacing);
        // forge-lint: disable-next-item(unsafe-typecast)
        position.liquidity = uint128(bound(position.liquidity, 1, maxLiquidityPerTick));

        return position;
    }

    function _givenPositionStakedTwice(StakedSlipstreamAM.PositionState memory position)
        internal
        pure
        returns (StakedSlipstreamAM.PositionState memory)
    {
        position = givenValidPosition(position, 1);

        // Both positions share the per tick liquidity cap.
        // forge-lint: disable-next-item(unsafe-typecast)
        position.liquidity = uint128(bound(position.liquidity, 1, tickSpacingToMaxLiquidityPerTick(1) / 2));
        return position;
    }

    function _givenPositionWithRoomAbove(StakedSlipstreamAM.PositionState memory position)
        internal
        pure
        returns (StakedSlipstreamAM.PositionState memory)
    {
        // Leave two ticks above the range, for the idle position the caller stakes there.
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 4));
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK - 2));
        return givenValidPosition(position, 1);
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
        (tokenId,,) = addLiquidityMetadex03CL(
            pool, position.liquidity, users.liquidityProvider, position.tickLower, position.tickUpper, false
        );
    }

    function _stakePosition(StakedSlipstreamAM.PositionState memory position) internal returns (uint256 assetId) {
        assetId = _stakePositionAs(position, users.liquidityProvider);
    }

    // Excludes the precompiles, every staged contract and the addresses a payout assertion reads.
    function _givenValidSecondOwner(address owner_) internal view {
        vm.assume(uint160(owner_) > 0xff);
        vm.assume(owner_.code.length == 0);
        vm.assume(owner_ != users.liquidityProvider);
        vm.assume(owner_ != surplusRecipient);
    }

    function addLiquidityAs(StakedSlipstreamAM.PositionState memory position, address owner_)
        internal
        returns (uint256 tokenId)
    {
        (tokenId,,) = addLiquidityMetadex03CL(
            pool, position.liquidity, owner_, position.tickLower, position.tickUpper, false
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _stakePositionAs(StakedSlipstreamAM.PositionState memory position, address owner_)
        internal
        returns (uint256 assetId)
    {
        assetId = addLiquidityAs(position, owner_);
        vm.startPrank(owner_);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);
        stakedMetadex03CLAM.mint(assetId);
        vm.stopPrank();
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _initStakedPositionWithEarned(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) internal returns (uint256 assetId) {
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);

        assetId = _stakePosition(position);

        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);
    }

    function _stageRoot() internal {
        _stageMetadex03CL(true);
        deployStakedMetadex03CLAM();
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _initRootHeldRewards(StakedSlipstreamAM.PositionState memory position, uint256 emissions, int24 tick)
        internal
        returns (uint256 held)
    {
        _stageRoot();
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);

        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.claimReward(assetId);

        held = pendingRedeemsOf(address(stakedMetadex03CLAM));
    }

    function _stakeRootPosition(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        uint256 rewardGrowthGlobalX128Last
    ) internal returns (uint256 assetId) {
        _stageRoot();

        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);

        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);
        assetId = _stakePosition(position);
    }

    function _initRootPositionWithEarned(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) internal returns (uint256 assetId) {
        _stageRoot();
        assetId = _initStakedPositionWithEarned(position, emissions, tick);
    }

    function _earned(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current
    ) internal view returns (uint256 earned) {
        uint256 rewardGrowthInsideX128;
        unchecked {
            rewardGrowthInsideX128 = rewardGrowthGlobalX128Current - rewardGrowthGlobalX128Last;
        }
        earned = FullMath.mulDiv(rewardGrowthInsideX128, getActualLiquidity(position), FixedPoint128.Q128);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function _stakeAndDeferEmissions(StakedSlipstreamAM.PositionState memory position, uint256 emissions, int24 tick)
        internal
        returns (uint256 deferredEmissions)
    {
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);

        setChainSuspended(true);
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.burn(assetId);
        setChainSuspended(false);

        deferredEmissions = gauge.deferredEmissions(address(stakedMetadex03CLAM));
    }

    function _stakeIdlePositionAbove(StakedSlipstreamAM.PositionState memory position)
        internal
        returns (uint256 assetId)
    {
        position.tickLower = position.tickUpper + 1;
        position.tickUpper = position.tickLower + 1;

        assetId = _stakePosition(position);
    }

    function initStakedPosition(StakedSlipstreamAM.PositionState memory position, int24 tick)
        internal
        returns (uint256 assetId)
    {
        deployAndAddGauge(tick);
        assetId = _stakePosition(position);
    }

    function deployAndAddGaugeAtPrices(int24 tick, uint256 priceToken0, uint256 priceToken1) internal {
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
        uint256 priceTokenA;
        uint256 priceTokenB;
        if (address(tokenA) < address(tokenB)) {
            (token0, token1) = (tokenA, tokenB);
            (priceTokenA, priceTokenB) = (priceToken0, priceToken1);
        } else {
            (token0, token1) = (tokenB, tokenA);
            (priceTokenA, priceTokenB) = (priceToken1, priceToken0);
        }
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tick), 300);
        gauge = createGaugeMetadex03CL(pool);
        // forge-lint: disable-next-line(unsafe-typecast)
        addAssetToArcadia(address(tokenA), int256(priceTokenA));
        // forge-lint: disable-next-line(unsafe-typecast)
        addAssetToArcadia(address(tokenB), int256(priceTokenB));

        vm.prank(users.owner);
        stakedMetadex03CLAM.addGauge(address(gauge));
    }

    function stageSwappablePosition(StakedSlipstreamAM.PositionState memory position, int24 tick, uint256 amountIn)
        internal
        returns (StakedSlipstreamAM.PositionState memory staged, uint256 assetId, uint256 amountIn_)
    {
        staged = givenValidPosition(position, 1);

        // The price limit must sit strictly below the current price and above MIN_SQRT_RATIO.
        // forge-lint: disable-next-line(unsafe-typecast)
        staged.tickLower = int24(bound(staged.tickLower, TickMath.MIN_TICK + 1, TickMath.MAX_TICK - 2));
        // forge-lint: disable-next-line(unsafe-typecast)
        staged.tickUpper = int24(bound(staged.tickUpper, staged.tickLower + 2, TickMath.MAX_TICK));
        // forge-lint: disable-next-line(unsafe-typecast)
        tick = int24(bound(tick, staged.tickLower + 1, staged.tickUpper - 1));

        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(staged.tickLower);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        // The narrowest sqrt price step sits at the lower bound.
        uint256 sqrtPriceStepX96 = TickMath.getSqrtRatioAtTick(staged.tickLower + 1) - sqrtPriceLowerX96;

        // The output clears the hook fee ceiling plus the wei the pool and the mint each floor.
        uint256 minAmount1 = 2 * SWAP_FEE_DENOMINATOR / (SWAP_FEE_DENOMINATOR - SWAP_FEE_CEIL) + 2;
        uint256 minLiquidity = minAmount1 * FixedPoint96.Q96 / sqrtPriceStepX96 + 1;
        // forge-lint: disable-next-line(unsafe-typecast)
        staged.liquidity = uint128(bound(staged.liquidity, minLiquidity, tickSpacingToMaxLiquidityPerTick(1)));

        assetId = initStakedPosition(staged, tick);

        // The minimum input covering the traversal and the hook fee.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint128 liquidity = uint128(getActualLiquidity(staged));
        uint256 traversal = LiquidityAmounts.getAmount0ForLiquidity(sqrtPriceLowerX96, sqrtPriceX96, liquidity) + 2;
        uint256 minAmountIn = traversal * 10 / 9 + 2;
        // The pool takes the input as an int256.
        // forge-lint: disable-next-line(unsafe-typecast)
        amountIn_ = bound(amountIn, minAmountIn, uint256(type(int256).max));
    }

    function swapThroughPool(StakedSlipstreamAM.PositionState memory position, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        deal(address(token0), users.swapper, amountIn, true);
        vm.startPrank(users.swapper);
        token0.approve(address(metadex03CLSwapRouter), amountIn);
        amountOut = metadex03CLSwapRouter.exactInputSingle(
            ICLSwapRouter.ExactInputSingleParams({
                tokenIn: address(token0),
                tokenOut: address(token1),
                tickSpacing: 1,
                recipient: users.swapper,
                deadline: type(uint256).max,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: TickMath.getSqrtRatioAtTick(position.tickLower)
            })
        );
        vm.stopPrank();
    }

    function getValuation(uint256 assetId)
        internal
        view
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedMetadex03CLAM)));
        bytes32[] memory underlyingAssetKeys = stakedMetadex03CLAM.getUnderlyingAssets(assetKey);
        (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
            stakedMetadex03CLAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, underlyingAssetKeys);
    }
}
