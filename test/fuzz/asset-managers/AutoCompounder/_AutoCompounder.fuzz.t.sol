/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { AutoCompounder, ExactInputSingleParams } from "../../../../src/asset-managers/AutoCompounder.sol";
import { AutoCompounderExtension } from "../../../utils/extensions/AutoCompounderExtension.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20Mock, ERC20 } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { FixedPoint96 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint96.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { SwapRouter02Fixture, ISwapRouter02 } from "../../../utils/fixtures/swap-router-02/SwapRouter02Fixture.f.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { UniswapV3Fixture } from "../../../utils/fixtures/uniswap-v3/UniswapV3Fixture.f.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Common logic needed by all "AutoCompounder" fuzz tests.
 */
abstract contract AutoCompounder_Fuzz_Test is Fuzz_Test, UniswapV3Fixture, SwapRouter02Fixture {
    using FixedPointMathLib for uint256;
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    int24 public MAX_TICK_VALUE = 887_272;
    uint256 public MOCK_ORACLE_DECIMALS = 18;
    uint24 public POOL_FEE = 100;
    uint256 public BIPS = 10_000;
    // 10 % price diff for testing
    uint256 public TOLERANCE = 1000;
    // $10
    uint256 public MIN_USD_FEES_VALUE = 10 * 1e18;
    uint256 public INITIATOR_FEE = 1000;

    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC20 public token0;
    ERC20 public token1;

    struct TestVariables {
        int24 tickLower;
        int24 tickUpper;
        uint112 amountToken0;
        uint112 amountToken1;
        // Fee amounts in usd
        uint256 feeAmount0;
        uint256 feeAmount1;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AutoCompounderExtension internal autoCompounder;
    IUniswapV3PoolExtension internal usdStablePool;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, UniswapV3Fixture) {
        Fuzz_Test.setUp();

        // Deploy fixture for Uniswap.
        UniswapV3Fixture.setUp();

        // Add two stable tokens with 6 and 18 decimals
        token0 = new ERC20Mock("Token 6d", "TOK6", 6);
        token1 = new ERC20Mock("Token 18d", "TOK18", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);

        // Tokens are added to the protocol
        addUnderlyingTokenToArcadia(address(token0), int256(10 ** MOCK_ORACLE_DECIMALS), 0, type(uint112).max);
        addUnderlyingTokenToArcadia(address(token1), int256(10 ** MOCK_ORACLE_DECIMALS), 0, type(uint112).max);

        // Calculate sqrtPriceX96 for pool init
        address[] memory assets = new address[](2);
        assets[0] = address(token0);
        assets[1] = address(token1);
        uint256[] memory assetIds = new uint256[](2);
        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1e18;
        assetAmounts[1] = 1e18;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registryExtension.getValuesInUsd(address(0), assets, assetIds, assetAmounts);

        uint160 sqrtPriceX96 = getSqrtPriceX96(valuesAndRiskFactors[0].assetValue, valuesAndRiskFactors[1].assetValue);

        // Init pool
        usdStablePool = createPool(token0, token1, sqrtPriceX96, 300);

        // Deploy SwapRouter fixture
        SwapRouter02Fixture.deploySwapRouter02(
            address(0), address(uniswapV3Factory), address(nonfungiblePositionManager), address(weth9)
        );

        vm.prank(users.creatorAddress);
        autoCompounder = new AutoCompounderExtension(
            address(registryExtension),
            address(uniswapV3Factory),
            address(nonfungiblePositionManager),
            address(swapRouter),
            TOLERANCE,
            MIN_USD_FEES_VALUE,
            INITIATOR_FEE
        );
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function getPrices() public view returns (uint256 usdPriceToken0, uint256 usdPriceToken1) {
        address[] memory assets = new address[](2);
        assets[0] = address(token0);
        assets[1] = address(token1);
        uint256[] memory assetIds = new uint256[](2);
        uint256[] memory assetAmounts = new uint256[](2);
        assetAmounts[0] = 1e18;
        assetAmounts[1] = 1e18;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registryExtension.getValuesInUsd(address(0), assets, assetIds, assetAmounts);

        usdPriceToken0 = valuesAndRiskFactors[0].assetValue;
        usdPriceToken1 = valuesAndRiskFactors[1].assetValue;
    }

    function getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public pure returns (uint160 sqrtPriceX96) {
        if (priceToken1 == 0) return TickMath.MAX_SQRT_RATIO;

        // Both priceTokens have 18 decimals precision and result of division should have 28 decimals precision.
        // -> multiply by 1e28
        // priceXd28 will overflow if priceToken0 is greater than 1.158e+49.
        // For WBTC (which only has 8 decimals) this would require a bitcoin price greater than 115 792 089 237 316 198 989 824 USD/BTC.
        uint256 priceXd28 = priceToken0.mulDivDown(1e28, priceToken1);
        // Square root of a number with 28 decimals precision has 14 decimals precision.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        // Change sqrtPrice from a decimal fixed point number with 14 digits to a binary fixed point number with 96 digits.
        // Unsafe cast: Cast will only overflow when priceToken0/priceToken1 >= 2^128.
        sqrtPriceX96 = uint160((sqrtPriceXd14 << FixedPoint96.RESOLUTION) / 1e14);
    }

    function givenValidBalancedState(TestVariables memory testVars)
        public
        view
        returns (TestVariables memory testVars_, bool token0HasLowestDecimals)
    {
        // Given : ticks should be in range
        int24 currentTick = usdStablePool.getCurrentTick();

        // And : tickRange is minimum 40
        testVars.tickUpper = int24(bound(testVars.tickUpper, currentTick + 10, currentTick + type(int16).max));
        // And : Liquidity is added in 50/50
        testVars.tickLower = currentTick - (testVars.tickUpper - currentTick);

        token0HasLowestDecimals = token0.decimals() < token1.decimals() ? true : false;

        // And : provide liquidity in balanced way.
        // Amount has no impact
        testVars.amountToken0 = token0HasLowestDecimals
            ? type(uint112).max / uint112((10 ** (token1.decimals() - token0.decimals())))
            : type(uint112).max;
        testVars.amountToken1 = token0HasLowestDecimals
            ? type(uint112).max
            : type(uint112).max / uint112((10 ** (token0.decimals() - token1.decimals())));

        // And : Position has accumulated fees (amount in USD)
        testVars.feeAmount0 = bound(testVars.feeAmount0, 100, type(uint16).max);
        testVars.feeAmount1 = bound(testVars.feeAmount1, 100, type(uint16).max);

        testVars_ = testVars;
    }

    function setState(TestVariables memory testVars, IUniswapV3PoolExtension pool) public returns (uint256 tokenId) {
        // Given : Mint initial position
        tokenId = addLiquidity(
            pool,
            testVars.amountToken0,
            testVars.amountToken1,
            users.liquidityProvider,
            testVars.tickLower,
            testVars.tickUpper
        );

        // And : Generate fees for the position
        generateFees(testVars.feeAmount0, testVars.feeAmount1);
    }

    function generateFees(uint256 amount0ToGenerate, uint256 amount1ToGenerate) public {
        // Swap token0 for token1
        uint256 amount0ToSwap = ((amount0ToGenerate * (1e6 / POOL_FEE)) * 10 ** token0.decimals());

        mintERC20TokenTo(address(token0), users.swapper, amount0ToSwap);

        vm.startPrank(users.swapper);
        token0.approve(address(swapRouter), amount0ToSwap);

        ISwapRouter02.ExactInputSingleParams memory exactInputParams = ISwapRouter02.ExactInputSingleParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            fee: POOL_FEE,
            recipient: users.swapper,
            amountIn: amount0ToSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactInputSingle(exactInputParams);

        // Swap token1 for token0
        uint256 amount1ToSwap = ((amount1ToGenerate * (1e6 / POOL_FEE)) * 10 ** token1.decimals());

        mintERC20TokenTo(address(token1), users.swapper, amount1ToSwap);
        token1.approve(address(swapRouter), amount1ToSwap);

        exactInputParams = ISwapRouter02.ExactInputSingleParams({
            tokenIn: address(token1),
            tokenOut: address(token0),
            fee: POOL_FEE,
            recipient: users.swapper,
            amountIn: amount1ToSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactInputSingle(exactInputParams);

        vm.stopPrank();
    }

    function createPool(ERC20 token0_, ERC20 token1_, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension pool)
    {
        address poolAddress = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(token0_), address(token1_), POOL_FEE, sqrtPriceX96
        ); // Set initial price to lowest possible price.
        pool = IUniswapV3PoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper
    ) public returns (uint256 tokenId) {
        address token0_ = pool.token0();
        address token1_ = pool.token1();
        uint24 fee = pool.fee();

        deal(token0_, liquidityProvider_, amount0);
        deal(token1_, liquidityProvider_, amount1);
        vm.startPrank(liquidityProvider_);
        ERC20Mock(token0_).approve(address(nonfungiblePositionManager), type(uint256).max);
        ERC20Mock(token1_).approve(address(nonfungiblePositionManager), type(uint256).max);
        (tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0_,
                token1: token1_,
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

    function addUnderlyingTokenToArcadia(address token, int256 price, uint112 initialExposure, uint112 maxExposure)
        internal
    {
        addUnderlyingTokenToArcadia(token, price);
        erc20AssetModule.setExposure(address(creditorUsd), token, initialExposure, maxExposure);
    }

    function addUnderlyingTokenToArcadia(address token, int256 price) internal {
        ArcadiaOracle oracle = initMockedOracle(uint8(MOCK_ORACLE_DECIMALS), "Token / USD");
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
}
