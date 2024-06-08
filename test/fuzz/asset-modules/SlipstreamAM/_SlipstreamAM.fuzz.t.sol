/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { SlipstreamFixture } from "../../../utils/fixtures/slipstream/Slipstream.f.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/Slipstream/NonfungiblePositionManager.sol";
import { SlipstreamAMExtension } from "../../../utils/extensions/SlipstreamAMExtension.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { VoterMock } from "../../../utils/mocks/Aerodrome/VoterMock.sol";

/**
 * @notice Common logic needed by all "SlipstreamAM" fuzz tests.
 */
abstract contract SlipstreamAM_Fuzz_Test is Fuzz_Test, SlipstreamFixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // While the true minimum value of an int256 is 2 ** 255, Solidity overflows on a negation (since INT256_MAX is one less).
    // -> This true minimum value will overflow and revert.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    VoterMock internal voter;
    SlipstreamAMExtension internal slipstreamAM;
    ICLPoolExtension internal poolStable1Stable2;
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

    function setUp() public virtual override(Fuzz_Test, SlipstreamFixture) {
        Fuzz_Test.setUp();
        SlipstreamFixture.setUp();

        // Deploy Aerodrome Voter.
        voter = new VoterMock(address(0));

        // Deploy fixture for Slipstream.
        deploySlipstream(address(voter));

        // Deploy mock for the Nonfungibleposition manager for tests where state of position must be fuzzed.
        deployNonfungiblePositionManagerMock();

        poolStable1Stable2 =
            createPoolCL(address(mockERC20.stable1), address(mockERC20.stable2), 1, TickMath.getSqrtRatioAtTick(0), 300);
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function deployNonfungiblePositionManagerMock() public {
        vm.prank(users.owner);
        nonfungiblePositionManagerMock = new NonfungiblePositionManagerMock(address(cLFactory));

        vm.label({ account: address(nonfungiblePositionManagerMock), newLabel: "NonfungiblePositionManagerMock" });
    }

    function deploySlipstreamAM(address nonfungiblePositionManager_) internal {
        // Deploy SlipstreamAM.
        vm.startPrank(users.owner);
        slipstreamAM = new SlipstreamAMExtension(address(registry), nonfungiblePositionManager_);

        vm.label({ account: address(slipstreamAM), newLabel: "Slipstream Asset Module" });

        // Add the Asset Module to the Registry.
        registry.addAssetModule(address(slipstreamAM));
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function isWithinAllowedRange(int24 tick) public pure returns (bool) {
        int24 MIN_TICK = -887_272;
        int24 MAX_TICK = -MIN_TICK;
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(MAX_TICK));
    }

    function addUnderlyingTokenToArcadia(address token, int256 price, uint112 initialExposure, uint112 maxExposure)
        internal
    {
        addUnderlyingTokenToArcadia(token, price);
        erc20AM.setExposure(address(creditorUsd), token, initialExposure, maxExposure);
    }

    function addUnderlyingTokenToArcadia(address token, int256 price) internal {
        ArcadiaOracle oracle = initMockedOracle(18, "Token / USD");
        address[] memory oracleArr = new address[](1);
        oracleArr[0] = address(oracle);

        vm.prank(users.transmitter);
        oracle.transmit(price);
        vm.startPrank(users.owner);
        uint80 oracleId = uint80(chainlinkOM.addOracle(address(oracle), "Token", "USD", 2 days));
        uint80[] memory oracleAssetToUsdArr = new uint80[](1);
        oracleAssetToUsdArr[0] = oracleId;

        erc20AM.addAsset(token, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleAssetToUsdArr));
        vm.stopPrank();

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(creditorUsd), token, 0, type(uint112).max, 80, 90);
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
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);
    }

    function givenValidPosition(NonfungiblePositionManagerMock.Position memory position)
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
    }
}
