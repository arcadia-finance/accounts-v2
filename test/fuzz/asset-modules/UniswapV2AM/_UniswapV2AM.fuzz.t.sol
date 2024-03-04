/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { UniswapV2PairMock } from "../../../utils/mocks/UniswapV2/UniswapV2PairMock.sol";
import { UniswapV2AMExtension } from "../../../utils/Extensions.sol";
import { UniswapV2FactoryMock } from "../../../utils/mocks/UniswapV2/UniswapV2FactoryMock.sol";
import { UniswapV2AM } from "../../../utils/mocks/asset-modules/UniswapV2AM.sol";

/**
 * @notice Common logic needed by all "UniswapV2AM" fuzz tests.
 */
abstract contract UniswapV2AM_Fuzz_Test is Fuzz_Test {
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

    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    UniswapV2AMExtension internal uniswapV2AM;

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
        uniswapV2AM = new UniswapV2AMExtension(address(registryExtension), address(uniswapV2Factory));
        registryExtension.addAssetModule(address(uniswapV2AM));
        vm.stopPrank();
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
        string memory label
    ) internal returns (ERC20Mock token) {
        token =
            new ERC20Mock(string(abi.encodePacked(label, " Mock")), string(abi.encodePacked("m", label)), tokenDecimals);
        oracleTokenToUsd = initMockedOracle(oracleTokenToUsdDecimals, string(abi.encodePacked(label, " / USD")), rate);

        vm.startPrank(users.creatorAddress);
        uint80 oracleId = uint80(chainlinkOM.addOracle(address(oracleTokenToUsd), "Mock", "USD", 2 days));
        uint80[] memory oracleTokenToUsdArr = new uint80[](1);
        oracleTokenToUsdArr[0] = oracleId;

        erc20AssetModule.addAsset(address(token), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleTokenToUsdArr));
        vm.stopPrank();

        vm.startPrank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(token), 0, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(token), 0, type(uint112).max, 0, 0
        );
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(token), 0, type(uint112).max, 0, 0
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
        uint256 amountOut = uniswapV2AM.getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut > 0) vm.assume(priceTokenOut <= type(uint256).max / amountOut);
        vm.assume(priceTokenIn <= type(uint256).max / amountIn);
        profit = priceTokenOut * amountOut - priceTokenIn * amountIn;
    }
}
