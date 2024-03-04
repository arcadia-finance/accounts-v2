/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { AerodromeVolatileAMExtension, FixedPointMathLib } from "../../../utils/Extensions.sol";
import { AerodromeFactoryMock } from "../../../utils/mocks/Aerodrome/AerodromeFactoryMock.sol";
import { AerodromePoolExtension } from "../../../utils/Extensions.sol";
import { FullMath } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";
import { PoolFactory } from "../../../utils/fixtures/aerodrome/AeroPoolFactoryFixture.f.sol";
import { Pool } from "../../../utils/fixtures/aerodrome/AeroPoolFixture.f.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";

/**
 * @notice Common logic needed by "AerodromeVolatileAM" fuzz tests.
 */
abstract contract AerodromeVolatileAM_Fuzz_Test is Fuzz_Test {
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

    AerodromeVolatileAMExtension internal aeroVolatileAM;
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

        // Deploy the Aerodrome AssetModule.
        vm.startPrank(users.creatorAddress);
        aeroVolatileAM = new AerodromeVolatileAMExtension(address(registryExtension), address(aeroFactoryMock));
        registryExtension.addAssetModule(address(aeroVolatileAM));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setMockState() public {
        // Given : The asset is a pool in the the Aerodrome Factory.
        aeroFactoryMock.setPool(address(aeroPoolMock));

        // Given : The asset is an Aerodrome Volatile pool.
        aeroPoolMock.setStable(false);

        // Given : Token0 and token1 are added to the Registry
        aeroPoolMock.setTokens(address(mockERC20.token1), address(mockERC20.stable1));
    }

    function deployAerodromeVolatileFixture(address token0, address token1) public {
        implementation = new Pool();
        poolFactory = new PoolFactory(address(implementation));

        address newPool = poolFactory.createPool(token0, token1, false);
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

        deployAerodromeVolatileFixture(address(token0), address(token1));

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

    function givenValidTestVars(TestVariables memory testVars) public view returns (TestVariables memory testVars_) {
        // Given : decimals should be max equal to 18
        // And : in order to avoid overflows we will assume no tokens with decimals lower than 4
        testVars.decimals0 = bound(testVars.decimals0, 4, 18);
        testVars.decimals1 = bound(testVars.decimals1, 4, 18);

        // And : "rateUnderlyingAssetsToUsd" for token0 and token1 does not overflows in "_getRateUnderlyingAssetsToUsd"
        // And : Avoid overflow and in fair reserves as described below
        testVars.priceToken1 = bound(testVars.priceToken1, 1, type(uint88).max);
        testVars.priceToken0 = bound(testVars.priceToken0, 1, type(uint88).max);

        vm.assume(testVars.priceToken0 != testVars.priceToken1);

        // And : Reserves should not be zero
        testVars.reserve1 = bound(testVars.reserve1, 4, type(uint112).max);
        testVars.reserve0 = bound(testVars.reserve1, 4, type(uint112).max);

        // And : In order to calculate the fair reserve 0, we have the following formula: r0' = sqrt((p1 * k) / p0).
        // Here we should avoid the highly unlikely situation where the division of p1 * k / p0 results in a number bigger than uint256.max.
        // In our case we should avoid that : assetValue1 * reserve0 * reserve1 / assetValue0 would end up bigger than uint256.max.
        // Therefore we are taking some assumptions, in order to be able to fuzz the max possible values.
        // In a normal situation if the price of an asset is higher than the other, the reserves of that asset should be lower than the other.
        // We will ensure the opposite in this test, as we would like to test for unbalanced pools (with reserves not representing actual price and ensuring that the faire reserves returns correct values).
        // That's why if the price of an asset is higher than the other we will set the reserves of the other, cheapest asset, equal to the sqrt of the reserves of the highest priced asset.
        // Also for big values, over uint72.max we will take the quadratic root, as when one value grows we would like the other to decrease to avoid overflows.

        // Note : Double check for situation with high price difference in favor of p1 and asset1 that has low decimals (and lower than asset0), which could lead to a result higher than uint256.max. Could this be a likely scenario ?

        if (testVars.priceToken1 > testVars.priceToken0) {
            testVars.reserve0 = testVars.reserve0 > type(uint72).max
                ? FixedPointMathLib.sqrt(FixedPointMathLib.sqrt(testVars.reserve0))
                : FixedPointMathLib.sqrt(testVars.reserve1);
        } else {
            testVars.reserve1 = testVars.reserve1 > type(uint72).max
                ? FixedPointMathLib.sqrt(FixedPointMathLib.sqrt(testVars.reserve1))
                : FixedPointMathLib.sqrt(testVars.reserve0);
        }

        // And : Sqrt of k should be greater than minimum liquidity
        // Note : check how we could keep the below
        //testVars.reserve1 = bound(testVars.reserve1, 10 ** 6 / testVars.reserve0, type(uint112).max);
        vm.assume(FixedPointMathLib.sqrt(testVars.reserve1 * testVars.reserve0) > 10 ** 3);

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
}
