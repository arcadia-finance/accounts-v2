/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromePoolAMExtension } from "../../../utils/extensions/AerodromePoolAMExtension.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { AerodromeFactoryMock } from "../../../utils/mocks/Aerodrome/AerodromeFactoryMock.sol";
import { FullMath } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { PoolFactory } from "../../../utils/fixtures/aerodrome/AeroPoolFactoryFixture.f.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by "AerodromePoolAM" fuzz tests.
 */
abstract contract AerodromePoolAM_Fuzz_Test is Fuzz_Test {
    using FixedPointMathLib for uint256;
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 MINIMUM_K = 10 ** 10;

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

    AerodromePoolAMExtension internal aeroPoolAM;
    AerodromeFactoryMock internal aeroFactoryMock;
    Pool internal aeroPoolMock;
    PoolFactory internal poolFactory;
    Pool internal pool;
    Pool internal implementation;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        // Deploy mocked Aerodrome contracts
        aeroFactoryMock = new AerodromeFactoryMock();
        aeroPoolMock = new Pool();

        // Deploy the Aerodrome AssetModule.
        vm.startPrank(users.creatorAddress);
        aeroPoolAM = new AerodromePoolAMExtension(address(registryExtension), address(aeroFactoryMock));
        registryExtension.addAssetModule(address(aeroPoolAM));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setMockState(bool stable) public {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Volatile pool.
        aeroPoolMock.setStable(stable);

        // Given : Token0 and token1 are added to the Registry
        aeroPoolMock.setTokens(address(mockERC20.token1), address(mockERC20.stable1));
    }

    function deployAerodromeFixture(address token0, address token1, bool stable) public {
        implementation = new Pool();
        poolFactory = new PoolFactory(address(implementation));

        address newPool = poolFactory.createPool(token0, token1, stable);
        pool = Pool(newPool);
    }

    function initAndSetValidStateInPoolFixture(TestVariables memory testVars)
        public
        returns (TestVariables memory testVars_)
    {
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(testVars.decimals0));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(testVars.decimals1));

        deployAerodromeFixture(address(token0), address(token1), testVars.stable);

        // And : The tokens of the pool are added to the Arcadia protocol
        addUnderlyingTokenToArcadia(address(token0), int256(testVars.priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(testVars.priceToken1));

        deal(address(token0), address(pool), testVars.reserve0);
        deal(address(token1), address(pool), testVars.reserve1);

        // And : A first position is minted
        testVars.liquidityAmount = pool.mint(users.accountOwner);

        testVars.token0 = address(token0);
        testVars.token1 = address(token1);

        testVars_ = testVars;
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

    function givenValidTestVarsVolatile(TestVariables memory testVars)
        public
        view
        returns (TestVariables memory testVars_)
    {
        // Given : Pool is volatile
        testVars.stable = false;

        // Given : decimals should be max equal to 18
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : "rateUnderlyingAssetsToUsd" for token0 and token1 does not overflows in "_getRateUnderlyingAssetsToUsd"
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 1e18);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 1e18);
        uint256 p0 = 10 ** (18 - testVars.decimals0) * testVars.priceToken0;
        uint256 p1 = 10 ** (18 - testVars.decimals1) * testVars.priceToken1;

        // And: Reserves should not be zero.
        // And: liquidity should be greater than minimum liquidity.
        // And: k should not overflow.
        testVars.reserve0 = bound(testVars.reserve0, 1, type(uint256).max);
        testVars.reserve1 = bound(testVars.reserve1, 1, type(uint256).max / testVars.reserve0);
        testVars.reserve1 =
            bound(testVars.reserve1, MINIMUM_LIQUIDITY ** 2 / testVars.reserve0, type(uint256).max / testVars.reserve0);
        uint256 k = testVars.reserve0 * testVars.reserve1;
        uint256 totalSupply = FixedPointMathLib.sqrt(k);

        // And: liquidity should be strictly greater than minimum liquidity.
        vm.assume(totalSupply > MINIMUM_LIQUIDITY);

        // And: trustedReserve0 does not overflow
        vm.assume(k / p0 < type(uint256).max / p1);
        uint256 trustedReserve0 = FixedPointMathLib.sqrt(FullMath.mulDiv(k, p1, p0));

        // trustedReserve1 can not overflow.
        uint256 trustedReserve1 = FullMath.mulDiv(trustedReserve0, p0, p1);

        // And: underlyingAssetsAmounts does not overflow.
        if (trustedReserve0 > 0) {
            testVars.assetAmount = bound(testVars.assetAmount, 0, type(uint256).max / trustedReserve0);
        }
        if (trustedReserve1 > 0) {
            testVars.assetAmount = bound(testVars.assetAmount, 0, type(uint256).max / trustedReserve1);
        }

        // And : assetAmount is maximum equal to pool totalSupply.
        testVars.assetAmount = bound(testVars.assetAmount, 0, totalSupply);

        testVars_ = testVars;
    }

    function givenValidTestVarsStable(TestVariables memory testVars)
        public
        view
        returns (TestVariables memory testVars_)
    {
        // Given : Pool is stable
        testVars.stable = true;

        // And : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);

        // Root (reserve0 * reserve1) should be greater than minimum liquidty
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k / 1e18 > MINIMUM_K);

        // And: d does not overflow.
        testVars.priceToken0 = bound(testVars.priceToken0, 1, 2 ** 127 - 1);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, 2 ** 127 - 1);
        uint256 p0 = testVars.priceToken0;
        uint256 p1 = testVars.priceToken1;
        uint256 d = p0 * p0 + p1 * p1;

        // And: c does not overflow
        vm.assume(k / p0 <= type(uint256).max / p1);
        uint256 c = FullMath.mulDiv(k, p1, p0);

        // And: x does not overflow.
        vm.assume(c / d <= type(uint256).max / 1e36);

        uint256 trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e36, c, d)));
        trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);
        uint256 trustedReserve1 = FullMath.mulDiv(
            trustedReserve0,
            10 ** (18 - testVars.decimals0) * testVars.priceToken0,
            10 ** (18 - testVars.decimals1) * testVars.priceToken1
        );
        if (trustedReserve0 > 0) {
            testVars.assetAmount = bound(testVars.assetAmount, 0, type(uint256).max / trustedReserve0);
        }
        if (trustedReserve1 > 0) {
            testVars.assetAmount = bound(testVars.assetAmount, 0, type(uint256).max / trustedReserve1);
        }

        // And : assetAmount is maximum equal to pool totalSupply.
        uint256 totalSupply = FixedPointMathLib.sqrt(testVars.reserve0 * testVars.reserve1);
        testVars.assetAmount = bound(testVars.assetAmount, 0, totalSupply);

        testVars_ = testVars;
    }

    function convertToDecimals(uint256 amount, uint256 assetDecimals, uint256 assetToDecimals)
        public
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
        public
        pure
        returns (uint256 k)
    {
        uint256 _x = reserve0 * 1e18 / decimals0;
        uint256 _y = reserve1 * 1e18 / decimals1;
        uint256 _a = _x * _y / 1e18;
        uint256 _b = (_x * _x + _y * _y) / 1e18;
        k = _a * _b;
    }

    function _k(uint256 reserve0, uint256 reserve1, uint256 decimals0, uint256 decimals1)
        public
        pure
        returns (uint256 k)
    {
        k = getK(reserve0, reserve1, decimals0, decimals1) / 1e18;
    }
}
