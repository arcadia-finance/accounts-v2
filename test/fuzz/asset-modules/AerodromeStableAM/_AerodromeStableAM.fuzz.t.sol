/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeStableAMExtension } from "../../../utils/Extensions.sol";
import { AerodromeFactoryMock } from "../../../utils/mocks/Aerodrome/AerodromeFactoryMock.sol";
import { AerodromePoolExtension } from "../../../utils/Extensions.sol";
import {
    Pool,
    PoolFactory,
    ERC20Mock,
    ArcadiaOracle,
    BitPackingLib,
    FixedPointMathLib
} from "../AerodromeVolatileAM/_AerodromeVolatileAM.fuzz.t.sol";

/**
 * @notice Common logic needed by "AerodromeStableAM" fuzz tests.
 */
abstract contract AerodromeStableAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 MINIMUM_K = 10 ** 10;

    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct TestVariables {
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

    AerodromeStableAMExtension internal aeroStableAM;
    AerodromeFactoryMock internal aeroFactoryMock;
    AerodromePoolExtension internal aeroPoolMock;
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
        aeroPoolMock = new AerodromePoolExtension();

        // Deploy the Aerodrome Stable AssetModule.
        vm.startPrank(users.creatorAddress);
        aeroStableAM = new AerodromeStableAMExtension(address(registryExtension), address(aeroFactoryMock));
        registryExtension.addAssetModule(address(aeroStableAM));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setMockState() public {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Stable pool.
        aeroPoolMock.setStable(true);

        // Given : Token0 and token1 are added to the Registry
        aeroPoolMock.setTokens(address(mockERC20.token1), address(mockERC20.stable1));
    }

    function deployAerodromeStableFixture(address token0, address token1) public {
        implementation = new Pool();
        poolFactory = new PoolFactory(address(implementation));

        address newPool = poolFactory.createPool(token0, token1, true);
        pool = Pool(newPool);
    }

    function initAndSetValidStateInPoolFixture(TestVariables memory testVars)
        public
        returns (TestVariables memory testVars_)
    {
        // Given : Valid test variables
        testVars_ = givenValidTestVars(testVars);

        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(testVars_.decimals0));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(testVars_.decimals1));

        deployAerodromeStableFixture(address(token0), address(token1));

        // And : The tokens of the pool are added to the Arcadia protocol
        addUnderlyingTokenToArcadia(address(token0), int256(testVars_.priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(testVars_.priceToken1));

        deal(address(token0), address(pool), testVars_.reserve0);
        deal(address(token1), address(pool), testVars_.reserve1);

        // And : A first position is minted
        testVars_.liquidityAmount = pool.mint(users.accountOwner);

        // And : assetAmount is greater than 0 and maximum equal to pool totalSupply.
        testVars_.assetAmount = bound(testVars_.assetAmount, 1, pool.totalSupply());
        // And : assetAmount is smaller or equal to uint112 max value (which is max value we can deposit in AM)
        testVars_.assetAmount = bound(testVars_.assetAmount, 1, type(uint112).max);

        testVars_.token0 = address(token0);
        testVars_.token1 = address(token1);
    }

    function givenValidTestVars(TestVariables memory testVars) public returns (TestVariables memory testVars_) {
        // Given : decimals should be max equal to 18.
        testVars.decimals0 = bound(testVars.decimals0, 0, 18);
        testVars.decimals1 = bound(testVars.decimals1, 0, 18);

        // And : "rateUnderlyingAssetsToUsd" for token0 and token1 does not overflows in "_getRateUnderlyingAssetsToUsd".
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint256).max / 10 ** 36);
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint256).max / 10 ** 36);

        // And : Reserves should not be zero and they should be deposited in same proportion.
        bool d0BiggerD1 = testVars.decimals0 > testVars.decimals1;
        uint256 decimalDifference = d0BiggerD1 ? 10 ** (testVars.decimals0 - testVars.decimals1) : 1;
        // And: k does not overflow (-> r <= sqrt(sqrt(type(uint256).max * 10 ** (4 * decimals - 36) / 2)))
        //                           -> r < 10 ** decimals * 15511800964 (approximated)
        testVars.reserve0 = bound(testVars.reserve0, decimalDifference, 15_511_800_964 * 10 ** testVars.decimals0);
        // And : Reserves should be deposited in same proportion for first mint.
        testVars.reserve0 = testVars.reserve0 / decimalDifference * decimalDifference;
        testVars.reserve1 = convertToDecimals(testVars.reserve0, testVars.decimals0, testVars.decimals1);
        emit log_named_uint("reserve1", testVars.reserve1);

        // root (reserve0 * reserve1) should be greater than minimum liquidty
        vm.assume(testVars.reserve0 * testVars.reserve1 > MINIMUM_LIQUIDITY ** 2);

        uint256 k = _k(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

        // k should be greater than minimum liquidity
        vm.assume(k > MINIMUM_K);

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
        uint256 _b = _x * _x / 1e18 + _y * _y / 1e18;
        k = _a * _b;
    }

    function _k(uint256 reserve0, uint256 reserve1, uint256 decimals0, uint256 decimals1)
        public
        pure
        returns (uint256 k)
    {
        uint256 _x = reserve0 * 1e18 / decimals0;
        uint256 _y = reserve1 * 1e18 / decimals1;
        uint256 _a = _x * _y / 1e18;
        uint256 _b = _x * _x / 1e18 + _y * _y / 1e18;
        k = _a * _b / 1e18;
    }
}
