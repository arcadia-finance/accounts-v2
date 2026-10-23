/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { Metadex03CLAMExtension } from "../../../utils/extensions/Metadex03CLAMExtension.sol";
import { Metadex03CLFixture } from "../../../utils/fixtures/metadex03/Metadex03CL.f.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/Slipstream/NonfungiblePositionManager.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Common logic needed by all "Metadex03CLAM" fuzz tests.
 */
// forge-lint: disable-next-item(unsafe-typecast)
abstract contract Metadex03CLAM_Fuzz_Test is Fuzz_Test, Metadex03CLFixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    // forge-lint: disable-next-line(mixed-case-variable)
    Metadex03CLAMExtension internal metadex03CLAM;
    ICLPoolExtension internal poolStable1Stable2;
    NonfungiblePositionManagerMock internal nonfungiblePositionManagerMock;

    struct TestVariables {
        uint256 decimals0;
        uint256 decimals1;
        int24 tickCurrent;
        int24 tickLower;
        int24 tickUpper;
        uint64 priceToken0;
        uint64 priceToken1;
        uint128 liquidity;
    }

    struct ProcessInputs {
        int24 tickCurrent;
        int24 tickLower;
        int24 tickUpper;
        uint16 riskFactor;
        uint112 initialExposure0;
        uint112 initialExposure1;
        uint112 maxExposure0;
        uint112 maxExposure1;
        uint112 maxUsdExposureProtocol;
        uint128 liquidity;
        uint128 liquidityIncrease;
        uint256 exposureUpperAssetToAsset;
        uint256 priceToken0;
        uint256 priceToken1;
    }

    struct UnderlyingAssetState {
        uint256 decimals;
        uint256 usdValue;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, Metadex03CLFixture) {
        Fuzz_Test.setUp();
        Metadex03CLFixture.setUp();

        // Deploy fixture for Metadex03 CL.
        deployMetadex03Periphery(false);
        deployMetadex03CL();

        // Deploy Metadex03 CL GaugeFactory.
        deployMetadex03CLGaugeFactory();

        // Deploy mock for the Nonfungibleposition manager for tests where state of position must be fuzzed.
        deployNonfungiblePositionManagerMock();

        poolStable1Stable2 = createPoolMetadex03CL(
            address(mockERC20.stable1), address(mockERC20.stable2), 1, TickMath.getSqrtRatioAtTick(0), 300
        );
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function deployNonfungiblePositionManagerMock() public {
        vm.prank(users.owner);
        nonfungiblePositionManagerMock = new NonfungiblePositionManagerMock(address(metadex03CLFactory));

        vm.label({ account: address(nonfungiblePositionManagerMock), newLabel: "NonfungiblePositionManagerMock" });
    }

    // forge-lint: disable-next-item(mixed-case-function)
    function deployMetadex03CLAM(address nonfungiblePositionManager_) internal {
        // Deploy Metadex03CLAM.
        vm.startPrank(users.owner);
        metadex03CLAM = new Metadex03CLAMExtension(users.owner, address(registry), nonfungiblePositionManager_);

        vm.label({ account: address(metadex03CLAM), newLabel: "Metadex03 CL Asset Module" });

        // Add the Asset Module to the Registry.
        registry.addAssetModule(address(metadex03CLAM));
        metadex03CLAM.setProtocol();
        vm.stopPrank();
    }

    function calculateAndValidateRangeTickCurrent(uint256 priceToken0, uint256 priceToken1)
        internal
        pure
        returns (uint256 sqrtPriceX96)
    {
        sqrtPriceX96 = FixedPointMathLib.sqrt(priceToken0 * 1e28 / priceToken1) * 2 ** 96 / 1e14;
    }

    function givenValidPosition(NonfungiblePositionManagerMock.Position memory position)
        internal
        pure
        returns (NonfungiblePositionManagerMock.Position memory)
    {
        vm.assume(position.poolId != 0);
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK));
        position.tickUpper = int24(bound(position.tickUpper, TickMath.MIN_TICK, TickMath.MAX_TICK));

        return position;
    }

    function principalAmountsAtPrice(uint256 assetId, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = metadex03PositionManager.positions(assetId);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }
}
