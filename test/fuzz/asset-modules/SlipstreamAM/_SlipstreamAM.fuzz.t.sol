/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import {
    LiquidityAmountsExtension
} from "../../../utils/fixtures/uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/Slipstream/NonfungiblePositionManager.sol";
import { SlipstreamAMExtension } from "../../../utils/extensions/SlipstreamAMExtension.sol";
import { SlipstreamFixture } from "../../../utils/fixtures/slipstream/Slipstream.f.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Common logic needed by all "SlipstreamAM" fuzz tests.
 */
// forge-lint: disable-next-item(unsafe-typecast)
abstract contract SlipstreamAM_Fuzz_Test is Fuzz_Test, SlipstreamFixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // Negating the true minimum of 2 ** 255 overflows, so this stops one below it.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-line(mixed-case-variable)
    SlipstreamAMExtension internal slipstreamAM;
    ICLPoolExtension internal poolStable1Stable2;
    NonfungiblePositionManagerMock internal nonfungiblePositionManagerMock;

    struct TestVariables {
        uint256 decimals0;
        uint256 decimals1;
        int24 tickCurrent;
        int24 tickLower;
        int24 tickUpper;
        uint64 priceToken0;
        uint64 priceToken1;
        uint128 liquidity;
    }

    struct ProcessInputs {
        int24 tickCurrent;
        int24 tickLower;
        int24 tickUpper;
        uint16 riskFactor;
        uint112 initialExposure0;
        uint112 initialExposure1;
        uint112 maxExposure0;
        uint112 maxExposure1;
        uint112 maxUsdExposureProtocol;
        uint128 liquidity;
        uint128 liquidityIncrease;
        uint256 exposureUpperAssetToAsset;
        uint256 priceToken0;
        uint256 priceToken1;
    }

    struct UnderlyingAssetState {
        uint256 decimals;
        uint256 usdValue;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, SlipstreamFixture) {
        Fuzz_Test.setUp();
        SlipstreamFixture.setUp();

        // Deploy fixture for Slipstream.
        deployAerodromePeriphery();
        deploySlipstream();

        // Deploy mock for the Nonfungibleposition manager for tests where state of position must be fuzzed.
        deployNonfungiblePositionManagerMock();

        poolStable1Stable2 = createPoolCL(
            address(mockERC20.stable1), address(mockERC20.stable2), 1, TickMath.getSqrtRatioAtTick(0), 300
        );
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function deployNonfungiblePositionManagerMock() public {
        vm.prank(users.owner);
        nonfungiblePositionManagerMock = new NonfungiblePositionManagerMock(address(cLFactory));

        vm.label({ account: address(nonfungiblePositionManagerMock), newLabel: "NonfungiblePositionManagerMock" });
    }

    // forge-lint: disable-next-item(mixed-case-function)
    function deploySlipstreamAM(address nonfungiblePositionManager_) internal {
        // Deploy SlipstreamAM.
        vm.startPrank(users.owner);
        slipstreamAM = new SlipstreamAMExtension(users.owner, address(registry), nonfungiblePositionManager_);

        vm.label({ account: address(slipstreamAM), newLabel: "Slipstream Asset Module" });

        // Add the Asset Module to the Registry.
        registry.addAssetModule(address(slipstreamAM));
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function calculateAndValidateRangeTickCurrent(uint256 priceToken0, uint256 priceToken1)
        internal
        pure
        returns (uint256 sqrtPriceX96)
    {
        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);
        sqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
    }

    function givenValidPosition(NonfungiblePositionManagerMock.Position memory position)
        internal
        pure
        returns (NonfungiblePositionManagerMock.Position memory)
    {
        // Given: poolId is non zero (=position is initialised).
        position.poolId = uint80(bound(position.poolId, 1, type(uint80).max));

        // And: Ticks are within allowed ranges.
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK));
        position.tickUpper = int24(bound(position.tickUpper, TickMath.MIN_TICK, TickMath.MAX_TICK));

        return position;
    }

    function principalAmountsAtPrice(uint256 assetId, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = slipstreamPositionManager.positions(assetId);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    function maxUnderlyingAmount(uint256 price) internal pure returns (uint256 maxAmount) {
        maxAmount = type(uint256).max / price / 1e18;
        if (maxAmount > type(uint112).max - 1) maxAmount = type(uint112).max - 1;
    }

    function givenValidLiquidity(ProcessInputs memory inputs, uint160 sqrtPriceX96, uint256 maxTickLiquidity)
        internal
        pure
        returns (uint128)
    {
        uint256 maxLiquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(inputs.tickLower),
            TickMath.getSqrtRatioAtTick(inputs.tickUpper),
            maxUnderlyingAmount(inputs.priceToken0),
            maxUnderlyingAmount(inputs.priceToken1)
        );
        vm.assume(maxLiquidity > 0);
        if (maxLiquidity > maxTickLiquidity) maxLiquidity = maxTickLiquidity;
        return uint128(bound(inputs.liquidity, 1, maxLiquidity));
    }
}
