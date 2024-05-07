/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { AutoCompounderExtension } from "../../../utils/extensions/AutoCompounderExtension.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20Mock, ERC20 } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/UniswapV3/NonfungiblePositionManager.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { ISwapRouter } from "../../../utils/fixtures/uniswap-v3/extensions/interfaces/ISwapRouter.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { UniswapV3Fixture } from "../../../utils/fixtures/uniswap-v3/UniswapV3Fixture.f.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Common logic needed by all "AutoCompounder" fuzz tests.
 */
abstract contract AutoCompounder_Fuzz_Test is Fuzz_Test, UniswapV3Fixture {
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    int24 public MAX_TICK_VALUE = 887_272;

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
        uint72 feeAmount0;
        uint72 feeAmount1;
        uint128 usdPriceToken0;
        uint128 usdPriceToken1;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AutoCompounderExtension internal autoCompounder;
    IUniswapV3PoolExtension internal usdStablePool;
    ISwapRouter internal swapRouter;
    NonfungiblePositionManagerMock internal nonfungiblePositionManagerMock;

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

        // Deploy mock for the Nonfungibleposition manager for tests where state of position must be fuzzed.
        // (we can't use the Fixture since most variables of the NonfungiblepositionExtension are private).
        deployNonfungiblePositionManagerMock();

        // Add two stable tokens with 6 and 18 decimals
        token0 = new ERC20Mock("Token 6d", "TOK6", 6);
        token1 = new ERC20Mock("Token 18d", "TOK18", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);

        usdStablePool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(0), 300);

        // Deploy SwapRouter fixture
        bytes memory args = abi.encode(address(uniswapV3Factory), address(weth9));
        bytes memory bytecode = abi.encodePacked(vm.getCode("SwapRouterExtension.sol"), args);
        address swapRouter_ = Utils.deployBytecode(bytecode);
        swapRouter = ISwapRouter(swapRouter_);

        vm.prank(users.creatorAddress);
        autoCompounder = new AutoCompounderExtension(
            address(registryExtension),
            address(uniswapV3Factory),
            address(nonfungiblePositionManagerMock),
            address(swapRouter)
        );
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function givenValidBalancedState(TestVariables memory testVars)
        public
        view
        returns (TestVariables memory testVars_)
    {
        // Given : ticks should be in range
        testVars.tickUpper = int24(bound(testVars.tickUpper, 0, MAX_TICK_VALUE));
        // And : tickLower = -tickUpper (initial balance state for stable pool)
        testVars.tickLower = -testVars.tickUpper;

        bool token0HasLowestDecimals = token0.decimals() == 6 ? true : false;

        // And : provide liquidity in balanced way (amount has no impact - should just be enough to swap fees)
        testVars.amountToken0 = token0HasLowestDecimals
            ? type(uint112).max / uint112((10 ** (token1.decimals() - token0.decimals())))
            : type(uint112).max;
        testVars.amountToken1 = token0HasLowestDecimals
            ? type(uint112).max
            : type(uint112).max / uint112((10 ** (token1.decimals() - token0.decimals())));

        // And : Position has accumulated fees
        testVars.feeAmount0 = uint72(bound(testVars.feeAmount0, 1, type(uint72).max));
        testVars.feeAmount1 = uint72(bound(testVars.feeAmount1, 1, type(uint72).max));

        // And : Prices are set
        // TODO : hardcoded for now
        testVars.usdPriceToken0 = token0HasLowestDecimals ? 1e30 : 1e18;
        testVars.usdPriceToken1 = token0HasLowestDecimals ? 1e18 : 1e30;

        testVars_ = testVars;
    }

    function deployNonfungiblePositionManagerMock() public {
        vm.prank(users.creatorAddress);
        nonfungiblePositionManagerMock = new NonfungiblePositionManagerMock(address(uniswapV3Factory));

        vm.label({ account: address(nonfungiblePositionManagerMock), newLabel: "NonfungiblePositionManagerMock" });
    }

    function createPool(ERC20 token0_, ERC20 token1_, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension pool)
    {
        address poolAddress = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(token0_), address(token1_), 100, sqrtPriceX96
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
}
