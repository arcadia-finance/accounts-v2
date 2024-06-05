/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { SlipstreamFixture } from "../../../utils/fixtures/slipstream/Slipstream.f.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FactoryRegistryMock } from "../../../utils/mocks/Aerodrome/FactoryRegistryMock.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { ICLGauge } from "../../../../src/asset-modules/Slipstream/interfaces/ICLGauge.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { LiquidityAmountsExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAMExtension } from "../../../utils/extensions/StakedSlipstreamAMExtension.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { VoterMock } from "../../../utils/mocks/Aerodrome/VoterMock.sol";

/**
 * @notice Common logic needed by all "StakedSlipstreamAM" fuzz tests.
 */
abstract contract StakedSlipstreamAM_Fuzz_Test is Fuzz_Test, SlipstreamFixture {
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    ArcadiaOracle internal aeroOracle;
    FactoryRegistryMock internal factoryRegistry;
    ICLPoolExtension internal pool;
    ICLGauge internal gauge;
    ERC20Mock internal token0;
    ERC20Mock internal token1;
    VoterMock internal voter;

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

        // Deploy Aerodrome Mocks.
        factoryRegistry = new FactoryRegistryMock();
        voter = new VoterMock(address(factoryRegistry));

        // Deploy fixture for Slipstream.
        deploySlipstream(address(voter));

        // Deploy fixture for CLGaugeFactory.
        deployCLGaugeFactory(address(voter));
        cLGaugeFactory.setNonfungiblePositionManager(address(slipstreamPositionManager));
        factoryRegistry.setFactoriesToPoolFactory(address(cLFactory), address(0), address(cLGaugeFactory));

        // Deploy AERO reward token.
        deployAero();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function deployAero() internal {
        // Mock Aero
        ERC20Mock rewardToken = new ERC20Mock("Aerodrome", "AERO", 18);
        vm.etch(AERO, address(rewardToken).code);
        aeroOracle = initMockedOracle(18, "AERO / USD", rates.token1ToUsd);

        // Add AERO to the ERC20PrimaryAM.
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(aeroOracle), "AERO", "USD", 2 days);
        uint80[] memory oracleAeroToUsdArr = new uint80[](1);
        oracleAeroToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(aeroOracle)));
        erc20AssetModule.addAsset(AERO, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAeroToUsdArr));
        vm.stopPrank();
    }

    function deployStakedSlipstreamAM() internal {
        // Deploy StakedSlipstreamAM.
        vm.startPrank(users.creatorAddress);
        stakedSlipstreamAM = new StakedSlipstreamAMExtension(
            address(registryExtension), address(slipstreamPositionManager), address(voter), address(AERO)
        );

        // Add the Asset Module to the Registry.
        registryExtension.addAssetModule(address(stakedSlipstreamAM));
        stakedSlipstreamAM.initialize();
        vm.stopPrank();
    }

    function deployPoolAndGauge(ERC20 tokenA_, ERC20 tokenB_, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (ERC20 token0_, ERC20 token1_)
    {
        (token0_, token1_) = tokenA_ < tokenB_ ? (tokenA_, tokenB_) : (tokenB_, tokenA_);
        address pool_ = cLFactory.createPool(address(token0_), address(token1_), 1, sqrtPriceX96);
        pool = ICLPoolExtension(pool_);
        pool.increaseObservationCardinalityNext(observationCardinality);

        vm.prank(address(voter));
        address gauge_ = cLGaugeFactory.createGauge(address(0), pool_, address(0), AERO, true);
        gauge = ICLGauge(gauge_);

        voter.setGauge(address(gauge));
        voter.setAlive(address(gauge), true);
    }

    function addUnderlyingTokenToArcadia(address token, int256 price) internal {
        ArcadiaOracle oracle = initMockedOracle(18, "Token / USD");
        address[] memory oracleArr = new address[](1);
        oracleArr[0] = address(oracle);

        vm.prank(users.defaultTransmitter);
        oracle.transmit(price);
        vm.startPrank(users.creatorAddress);
        uint80 oracleId = uint80(chainlinkOM.addOracle(address(oracle), "Token", "USD", 2 days));
        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = oracleId;

        erc20AssetModule.addAsset(token, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
        vm.stopPrank();

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), token, 0, type(uint112).max, 80, 90);
    }

    function deployAndAddGauge() internal {
        deployAndAddGauge(0);
    }

    function deployAndAddGauge(int24 tick) internal {
        ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
        ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        deployPoolAndGauge(token0, token1, TickMath.getSqrtRatioAtTick(tick), 300);
        addUnderlyingTokenToArcadia(address(token0), 1e18);
        addUnderlyingTokenToArcadia(address(token1), 1e18);

        vm.prank(users.creatorAddress);
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
        view
        returns (StakedSlipstreamAM.PositionState memory)
    {
        // Given: Ticks are within allowed ranges.
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK));

        uint256 maxLiquidityPerTick = tickSpacingToMaxLiquidityPerTick(tickSpacing);
        position.liquidity = uint128(bound(position.liquidity, 1, maxLiquidityPerTick));

        return position;
    }

    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
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
        tokenId = addLiquidity(
            pool, position.liquidity, users.liquidityProvider, position.tickLower, position.tickUpper, false
        );
    }

    function addLiquidity(
        ICLPoolExtension pool_,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        (uint160 sqrtPrice,,,,,) = pool_.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        tokenId =
            addLiquidity(pool_, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidity(
        ICLPoolExtension pool_,
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
            (uint160 sqrtPrice,,,,,) = pool_.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        address token0_ = pool.token0();
        address token1_ = pool.token1();
        int24 tickSpacing = pool.tickSpacing();

        deal(token0_, liquidityProvider_, amount0);
        deal(token1_, liquidityProvider_, amount1);
        vm.startPrank(liquidityProvider_);
        ERC20(token0_).approve(address(slipstreamPositionManager), type(uint256).max);
        ERC20(token1_).approve(address(slipstreamPositionManager), type(uint256).max);
        (tokenId,,,) = slipstreamPositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0_,
                token1: token1_,
                tickSpacing: tickSpacing,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider_,
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );
        vm.stopPrank();
    }
}
