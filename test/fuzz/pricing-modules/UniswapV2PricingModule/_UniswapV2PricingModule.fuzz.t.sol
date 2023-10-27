/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { OracleHub } from "../../../../src/OracleHub.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";
import { UniswapV2PairMock } from "../../../utils/mocks/UniswapV2PairMock.sol";
import { UniswapV2PricingModuleExtension } from "../../../utils/Extensions.sol";
import { UniswapV2FactoryMock } from "../../../utils/mocks/UniswapV2FactoryMock.sol";

/**
 * @notice Common logic needed by all "UniswapV2PricingModule" fuzz tests.
 */
abstract contract UniswapV2PricingModule_Fuzz_Test is Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    address internal constant haydenAdams = address(10);
    address internal constant lpProvider = address(11);

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    UniswapV2FactoryMock internal uniswapV2Factory;
    UniswapV2PairMock internal uniswapV2Pair;
    UniswapV2PairMock internal pairToken1Token2;
    UniswapV2PairMock internal pairToken1Token3;

    ArcadiaOracle internal oracleToken2ToUsd;

    uint16 internal collateralFactor = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
    uint16 internal liquidationFactor = RiskConstants.DEFAULT_LIQUIDATION_FACTOR;

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    UniswapV2PricingModuleExtension internal uniswapV2PricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(haydenAdams);
        uniswapV2Factory = new UniswapV2FactoryMock();
        uniswapV2Pair = new UniswapV2PairMock();
        address pairToken1Token2Addr = uniswapV2Factory.createPair(address(mockERC20.token2), address(mockERC20.token1));
        pairToken1Token2 = UniswapV2PairMock(pairToken1Token2Addr);
        address pairToken1Token3Addr = uniswapV2Factory.createPair(address(mockERC20.token3), address(mockERC20.token1));
        pairToken1Token3 = UniswapV2PairMock(pairToken1Token3Addr);
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        uniswapV2PricingModule = new UniswapV2PricingModuleExtension(
            address(mainRegistryExtension),
            address(uniswapV2Factory)
        );
        mainRegistryExtension.addPricingModule(address(uniswapV2PricingModule));
        vm.stopPrank();

        oracleToken2ToUsdArr = new address[](1);
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/
    function assertInRange(uint256 actualValue, uint256 expectedValue, uint8 precision) internal {
        if (expectedValue == 0) {
            assertEq(actualValue, expectedValue);
        } else {
            vm.assume(expectedValue > 10 ** (2 * precision));
            assertGe(actualValue * (10 ** precision + 1) / 10 ** precision, expectedValue);
            assertLe(actualValue * (10 ** precision - 1) / 10 ** precision, expectedValue);
        }
    }

    function deployToken(
        ArcadiaOracle oracleTokenToUsd,
        uint8 tokenDecimals,
        uint8 oracleTokenToUsdDecimals,
        uint256 rate,
        string memory label,
        address[] memory oracleTokenToUsdArr
    ) internal returns (ERC20Mock token) {
        token =
            new ERC20Mock(string(abi.encodePacked(label, " Mock")), string(abi.encodePacked("m", label)), tokenDecimals);
        oracleTokenToUsd = initMockedOracle(oracleTokenToUsdDecimals, string(abi.encodePacked(label, " / USD")), rate);
        oracleTokenToUsdArr[0] = address(oracleTokenToUsd);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** oracleTokenToUsdDecimals),
                baseAsset: bytes8(abi.encodePacked(label)),
                quoteAsset: "USD",
                oracle: address(oracleTokenToUsd),
                baseAssetAddress: address(token),
                isActive: true
            })
        );
        erc20PricingModule.addAsset(address(token), oracleTokenToUsdArr, emptyRiskVarInput);
        vm.stopPrank();

        vm.startPrank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(token), 0, type(uint128).max, 0, 0
        );
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(token), 0, type(uint128).max, 0, 0
        );
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(token), 0, type(uint128).max, 0, 0
        );
        vm.stopPrank();
    }

    function profitArbitrage(
        uint256 priceTokenIn,
        uint256 priceTokenOut,
        uint256 amountIn,
        uint112 reserveIn,
        uint112 reserveOut
    ) internal view returns (uint256 profit) {
        uint256 amountOut = uniswapV2PricingModule.getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut > 0) vm.assume(priceTokenOut <= type(uint256).max / amountOut);
        vm.assume(priceTokenIn <= type(uint256).max / amountIn);
        profit = priceTokenOut * amountOut - priceTokenIn * amountIn;
    }
}
