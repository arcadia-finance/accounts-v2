/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Test } from "../../../Base.t.sol";
import { BaseHook } from "../../../../lib/v4-periphery-fork/src/base/hooks/BaseHook.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Hooks } from "../../../../lib/v4-periphery-fork/lib/v4-core/libraries/Hooks.sol";
import { IAllowanceTransfer } from "../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
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

    struct UnderlyingAssetState {
        uint256 decimals;
        uint256 usdValue;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, UniswapV4Fixture) {
        Fuzz_Test.setUp();
        // Deploy fixture for UniswapV4
        UniswapV4Fixture.setUp();

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

    function deployHook(uint160[] memory hooks, string memory hookInstance) public returns (address arbitraryAddress) {
        // Set flags for hooks to implement
        uint160 flags;
        for (uint256 i; i < hooks.length; i++) {
            flags = flags | hooks[i];
        }

        // Here we deploy to an arbitrary address to avoid waiting to find the right salt with the HookFinder.
        arbitraryAddress = address(flags);

        deployCodeTo(hookInstance, abi.encode(poolManager), arbitraryAddress);
    }

    function initializePool(
        address token0,
        address token1,
        uint160 sqrtPriceX96,
        address hook,
        uint24 fee,
        int24 tickSpacing
    ) public returns (PoolKey memory poolKey) {
        if (address(token0) > address(token1)) {
            (token0, token1) = (Currency.wrap(address(token1)), Currency.wrap(address(token0)));
        } else {
            (token0, token1) = (Currency.wrap(address(token0)), Currency.wrap(address(token1)));
        }

        poolKey =
            PoolKey({ currency0: token0, currency1: token1, fee: fee, tickSpacing: tickSpacing, hooks: BaseHook(hook) });

        // Initialize pool
        poolManager.initialize(poolKey, sqrtPriceX96, "");
    }

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

    /*     function givenValidPosition(NonfungiblePositionManagerMock.Position memory position)
        internal
        view
        returns (NonfungiblePositionManagerMock.Position memory)
    {
        // Given: poolId is non zero (=position is initialised).
        position.poolId = uint80(bound(position.poolId, 1, type(uint80).max));

        // And: Ticks are within allowed ranges.
        vm.assume(isWithinAllowedRange(position.tickLower));
        vm.assume(isWithinAllowedRange(position.tickUpper));

        return position;
    } */
}
