/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { Metadex03Fixture } from "../../../utils/fixtures/metadex03/Metadex03Fixture.f.sol";
import { Metadex03PoolAMExtension } from "../../../utils/extensions/Metadex03PoolAMExtension.sol";

/**
 * @notice Common logic needed by "Metadex03PoolAM" fuzz tests.
 */
abstract contract Metadex03PoolAM_Fuzz_Test is Fuzz_Test, Metadex03Fixture {
    using FixedPointMathLib for uint256;
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 internal constant MINIMUM_K = 10 ** 10;

    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct TestVariables {
        bool stable;
        uint256 decimals0;
        uint256 decimals1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 priceToken0;
        uint256 priceToken1;
        uint256 assetAmount;
        uint256 liquidityAmount;
        address token0;
        address token1;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-line(mixed-case-variable)
    Metadex03PoolAMExtension internal metadex03PoolAM;
    IMetadex03V2Pool internal metadex03Pool;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy the Metadex03 contracts
        deployMetadex03Periphery();
        deployMetadex03();
        metadex03Pool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Deploy the Metadex03 AssetModule.
        vm.startPrank(users.owner);
        metadex03PoolAM = new Metadex03PoolAMExtension(
            users.owner, address(registry), address(stablePoolFactory), address(volatilePoolFactory)
        );
        registry.addAssetModule(address(metadex03PoolAM));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function initAndSetValidStateInPoolFixture(TestVariables memory testVars)
        internal
        returns (TestVariables memory testVars_)
    {
        // forge-lint: disable-next-item(unsafe-typecast)
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(testVars.decimals0));
        ERC20Mock token1;
        while (address(token1) < address(token0)) {
            // forge-lint: disable-next-item(unsafe-typecast)
            token1 = new ERC20Mock("Token 1", "TOK1", uint8(testVars.decimals1));
        }

        metadex03Pool = createPoolMetadex03(address(token0), address(token1), testVars.stable);

        // And: The tokens of the metadex03Pool are added to the Arcadia protocol
        // forge-lint: disable-next-item(unsafe-typecast)
        addAssetToArcadia(address(token0), int256(testVars.priceToken0));
        // forge-lint: disable-next-item(unsafe-typecast)
        addAssetToArcadia(address(token1), int256(testVars.priceToken1));

        deal(address(token0), address(metadex03Pool), testVars.reserve0);
        deal(address(token1), address(metadex03Pool), testVars.reserve1);

        // And: A first position is minted
        testVars.liquidityAmount = metadex03Pool.mint(users.accountOwner);

        testVars.token0 = address(token0);
        testVars.token1 = address(token1);

        testVars_ = testVars;
    }

    function givenValidTestVarsVolatile(TestVariables memory testVars)
        internal
        pure
        returns (TestVariables memory testVars_)
    {
        // And: The pool is volatile.
        testVars.stable = false;

        // And: Both tokens have supported decimals.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And: The usd rates of both tokens do not overflow in "_getRateUnderlyingAssetsToUsd".
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Both reserves are non zero and their product, the invariant k, does not overflow.
        vm.assume(testVars.reserve0 != 0);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;
        uint256 totalSupply = FixedPointMathLib.sqrt(k);

        // And: The first mint yields at least the minimum liquidity the pool requires.
        vm.assume(totalSupply >= 2 * MINIMUM_LIQUIDITY);

        // And: The trusted reserves do not overflow.
        vm.assume(k / p0 < type(uint256).max / p1);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(FullMath.mulDiv(k, p1, p0));
        uint256 trustedReserve1 = FullMath.mulDiv(trustedReserve0, p0, p1);

        // And: The asset amount is at most the minted supply and the underlying amounts do not overflow.
        uint256 maxAmount = totalSupply - MINIMUM_LIQUIDITY;
        if (trustedReserve0 > 0 && type(uint256).max / trustedReserve0 < maxAmount) {
            maxAmount = type(uint256).max / trustedReserve0;
        }
        if (trustedReserve1 > 0 && type(uint256).max / trustedReserve1 < maxAmount) {
            maxAmount = type(uint256).max / trustedReserve1;
        }
        testVars.assetAmount = bound(testVars.assetAmount, 0, maxAmount);

        testVars_ = testVars;
    }

    function givenValidTestVarsStable(TestVariables memory testVars)
        internal
        pure
        returns (TestVariables memory testVars_)
    {
        // And: The pool is stable.
        testVars.stable = true;

        // And: Both tokens have supported decimals.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And: Both reserves are below the maximum supply supported for stable pools, in the same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // forge-lint: disable-next-item(divide-before-multiply)
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // And: The first mint yields at least the minimum liquidity and clears the minimum invariant of the pool.
        vm.assume(FixedPointMathLib.sqrt(testVars.reserve0 * testVars.reserve1) >= 2 * MINIMUM_LIQUIDITY);
        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: The ratio of the sum over the difference of the usd rates does not overflow.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, 2 ** 127 - 1);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, 2 ** 127 - 1);

        // And: The trusted reserves do not round to zero.
        uint256 q = getRatio(testVars.priceToken0, testVars.priceToken1);
        vm.assume(q >= 16);

        // And: The asset amount is at most the total supply, so the underlying amounts do not overflow.
        testVars.assetAmount =
            bound(testVars.assetAmount, 0, FixedPointMathLib.sqrt(testVars.reserve0 * testVars.reserve1));

        testVars_ = testVars;
    }

    function convertToDecimals(uint256 amount, uint256 assetDecimals, uint256 assetToDecimals)
        internal
        pure
        returns (uint256 convertedAmount)
    {
        convertedAmount = amount;

        if (assetDecimals < assetToDecimals) {
            convertedAmount *= 10 ** (assetToDecimals - assetDecimals);
        } else if (assetDecimals > assetToDecimals) {
            convertedAmount /= 10 ** (assetDecimals - assetToDecimals);
        }
    }

    function getK(uint256 reserve0, uint256 reserve1, uint256 decimals0, uint256 decimals1)
        internal
        pure
        returns (uint256 k)
    {
        uint256 _x = reserve0 * 1e18 / decimals0;
        uint256 _y = reserve1 * 1e18 / decimals1;
        // forge-lint: disable-next-item(divide-before-multiply)
        uint256 _a = _x * _y / 1e18;
        // forge-lint: disable-next-item(divide-before-multiply)
        uint256 _b = (_x * _x + _y * _y) / 1e18;
        // forge-lint: disable-next-item(divide-before-multiply)
        k = _a * _b;
    }

    function getRatio(uint256 p0, uint256 p1) internal pure returns (uint256 q) {
        q = p0 < p1 ? p0 * 1e18 / p1 : p1 * 1e18 / p0;
    }

    function getMarginalPrice(uint256 x, uint256 y) internal pure returns (uint256 marginalPrice) {
        uint256 x2 = FullMath.mulDiv(x, x, 1e18);
        uint256 y2 = FullMath.mulDiv(y, y, 1e18);
        uint256 numerator = FullMath.mulDiv(3 * x2, y, 1e18) + FullMath.mulDiv(y2, y, 1e18);
        uint256 denominator = FullMath.mulDiv(x2, x, 1e18) + FullMath.mulDiv(3 * x, y2, 1e18);
        marginalPrice = FullMath.mulDiv(numerator, 1e18, denominator);
    }
}
