/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Test } from "../../../Base.t.sol";
import { BaseHook } from "../../../../lib/v4-periphery-fork/src/base/hooks/BaseHook.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Hooks } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Hooks.sol";
import { PoolManager } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/PoolManager.sol";
import { PoolKey } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PositionManager } from "../../../../lib/v4-periphery-fork/src/PositionManager.sol";
import { StateView } from "../../../../lib/v4-periphery-fork/src/lens/StateView.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AMExtension } from "../../../../test/utils/extensions/UniswapV4AMExtension.sol";
import { UniswapV4Fixture } from "../../../utils/fixtures/uniswap-v4/UniswapV4Fixture.f.sol";

/**
 * @notice Common logic needed by all "UniswapV4AM" fuzz tests.
 */
abstract contract UniswapV4AM_Fuzz_Test is Fuzz_Test, UniswapV4Fixture {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    UniswapV4AMExtension internal uniswapV4AM;
    PoolKey internal stablePoolKey;
    PoolKey internal randomPoolKey;

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // While the true minimum value of an int256 is 2 ** 255, Solidity overflows on a negation (since INT256_MAX is one less).
    // -> This true minimum value will overflow and revert.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct TestVariables {
        uint256 decimals0;
        uint256 decimals1;
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
        uint64 priceToken0;
        uint64 priceToken1;
        uint80 liquidity;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, UniswapV4Fixture) {
        Fuzz_Test.setUp();
        // Deploy fixture for UniswapV4
        vm.startPrank(users.owner);
        UniswapV4Fixture.setUp();
        vm.stopPrank();

        // Initializes a pool
        stablePoolKey = initializePool(
            address(mockERC20.stable1),
            address(mockERC20.stable2),
            TickMath.getSqrtPriceAtTick(0),
            address(validHook),
            500,
            1
        );

        // Deploy Asset-Module
        vm.startPrank(users.owner);
        uniswapV4AM = new UniswapV4AMExtension(address(registry), address(positionManager), address(stateView));
        registry.addAssetModule(address(uniswapV4AM));
        uniswapV4AM.setProtocol();
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function calculateAndValidateRangeTickCurrent(uint256 priceToken0, uint256 priceToken1)
        internal
        pure
        returns (uint256 sqrtPriceX96)
    {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 10 ** 28);
        vm.assume(priceToken1 <= type(uint256).max / 10 ** 18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        // sqrtPriceX96 must be within ranges, or TickMath reverts.
        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);
        sqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
        vm.assume(sqrtPriceX96 >= MIN_SQRT_PRICE);
        vm.assume(sqrtPriceX96 <= MAX_SQRT_PRICE);
    }

    function givenValidTicks(int24 tickLower, int24 tickUpper)
        public
        view
        returns (int24 tickLower_, int24 tickUpper_)
    {
        tickLower_ = int24(bound(tickLower, MIN_TICK, MAX_TICK - 2));
        tickUpper_ = int24(bound(tickUpper, tickLower_ + 1, MAX_TICK));
    }
}
