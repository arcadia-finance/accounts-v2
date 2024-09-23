/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Test } from "../../../Base.t.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IAllowanceTransfer } from "../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { PoolManager } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/PoolManager.sol";
import { PositionManager } from "../../../../lib/v4-periphery-fork/src/PositionManager.sol";
import { StateView } from "../../../../lib/v4-periphery-fork/src/lens/StateView.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AMExtension } from "../../../../test/utils/extensions/UniswapV4AMExtension.sol";

/**
 * @notice Common logic needed by all "UniswapV4AM" fuzz tests.
 */
abstract contract UniswapV4AM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    PoolManager public poolManager;
    PositionManager internal positionManager;
    StateView internal stateView;
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

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
        // Deploy Pool Manager
        poolManager = new PoolManager();

        // Deploy StateView contract
        stateView = new StateView(poolManager);

        // Deploy Position Manager
        positionManager = new PositionManager(poolManager, IAllowanceTransfer(address(0)), 0);

        // Deploy Asset-Module
        uniswapV4AM = new UniswapV4AMExtension(address(registry), address(positionManager), address(stateView));
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
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);
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
