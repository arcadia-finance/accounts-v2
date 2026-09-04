/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Test } from "../../../Base.t.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { UniswapV3Fixture } from "../../../utils/fixtures/uniswap-v3/UniswapV3Fixture.f.sol";
import { UniswapV3AMFixture } from "../../../utils/fixtures/arcadia-accounts/UniswapV3AMFixture.f.sol";

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {
    IUniswapV3PoolExtension
} from "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/UniswapV3/NonfungiblePositionManager.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Common logic needed by all "UniswapV3AM" fuzz tests.
 */
// forge-lint: disable-next-item(unsafe-typecast)
abstract contract UniswapV3AM_Fuzz_Test is Fuzz_Test, UniswapV3Fixture, UniswapV3AMFixture {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // Negating the true minimum of 2 ** 255 overflows, so this stops one below it.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    IUniswapV3PoolExtension internal poolStable1Stable2;
    NonfungiblePositionManagerMock internal nonfungiblePositionManagerMock;

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

    function setUp() public virtual override(Fuzz_Test, UniswapV3Fixture, Base_Test) {
        Fuzz_Test.setUp();
        // Deploy fixture for Uniswap.
        UniswapV3Fixture.setUp();

        // Deploy mock for the Nonfungibleposition manager for tests where state of position must be fuzzed.
        // (we can't use the Fixture since most variables of the NonfungiblepositionExtension are private).
        deployNonfungiblePositionManagerMock();

        poolStable1Stable2 = createPoolUniV3(
            address(mockERC20.stable1), address(mockERC20.stable2), 100, TickMath.getSqrtRatioAtTick(0), 300
        );
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function deployNonfungiblePositionManagerMock() public {
        vm.prank(users.owner);
        nonfungiblePositionManagerMock = new NonfungiblePositionManagerMock(address(uniswapV3Factory));

        vm.label({ account: address(nonfungiblePositionManagerMock), newLabel: "NonfungiblePositionManagerMock" });
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
}
