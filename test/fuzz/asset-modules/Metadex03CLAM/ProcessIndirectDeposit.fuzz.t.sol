/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { SlipstreamAM } from "../../../../src/asset-modules/Slipstream/SlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ProcessIndirectDeposit_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC20 token0;
    ERC20 token1;
    ICLPoolExtension pool;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(metadex03PositionManager));

        token0 = new ERC20Mock("Token 0", "TOK0", 18);
        token1 = new ERC20Mock("Token 1", "TOK1", 18);
        (token0, token1) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_BadDepositAmount(
        int256 deltaExposureUpperAssetToAsset,
        ProcessInputs memory inputs
    ) public {
        // Given: An initialised pool of the two underlying tokens, priced at the ratio of their usd prices.
        (inputs.priceToken0, inputs.priceToken1) = givenValidPrices(inputs.priceToken0, inputs.priceToken1);
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(inputs.priceToken0, inputs.priceToken1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, sqrtPriceX96, 300);

        // And: A valid liquidity position in that pool.
        inputs.tickLower = int24(bound(inputs.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        inputs.tickUpper = int24(bound(inputs.tickUpper, inputs.tickLower + 1, TickMath.MAX_TICK));
        inputs.liquidity = uint128(bound(inputs.liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, inputs.liquidity, users.liquidityProvider, inputs.tickLower, inputs.tickUpper, false
        );

        // And: The change in exposure of the upper asset is neither zero nor one.
        vm.assume(deltaExposureUpperAssetToAsset != 0);
        vm.assume(deltaExposureUpperAssetToAsset != 1);

        // When: An indirect deposit of the position is processed.
        // Then: It reverts.
        vm.prank(address(registry));
        vm.expectRevert(SlipstreamAM.InvalidAmount.selector);
        metadex03CLAM.processIndirectDeposit(
            address(creditorUsd),
            address(metadex03PositionManager),
            tokenId,
            inputs.exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );
    }

    function testFuzz_Revert_processIndirectDeposit_NonRegistry(
        address unprivilegedAddress,
        ProcessInputs memory inputs
    ) public {
        // Given: An initialised pool of the two underlying tokens, priced at the ratio of their usd prices.
        (inputs.priceToken0, inputs.priceToken1) = givenValidPrices(inputs.priceToken0, inputs.priceToken1);
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(inputs.priceToken0, inputs.priceToken1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, sqrtPriceX96, 300);

        // And: A valid liquidity position in that pool.
        inputs.tickLower = int24(bound(inputs.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        inputs.tickUpper = int24(bound(inputs.tickUpper, inputs.tickLower + 1, TickMath.MAX_TICK));
        inputs.liquidity = uint128(bound(inputs.liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, inputs.liquidity, users.liquidityProvider, inputs.tickLower, inputs.tickUpper, false
        );

        // And: The caller is not the Registry.
        vm.assume(unprivilegedAddress != address(registry));

        // When: An indirect deposit of one position is processed.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        metadex03CLAM.processIndirectDeposit(
            address(creditorUsd), address(metadex03PositionManager), tokenId, inputs.exposureUpperAssetToAsset, 1
        );
    }

    function testFuzz_Success_processIndirectDeposit_DepositAmountOne(ProcessInputs memory inputs) public {
        // Given: An initialised pool of the two underlying tokens, priced at the ratio of their usd prices.
        (inputs.priceToken0, inputs.priceToken1) = givenValidPrices(inputs.priceToken0, inputs.priceToken1);
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(inputs.priceToken0, inputs.priceToken1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, sqrtPriceX96, 300);

        // And: A valid liquidity position in that pool.
        inputs.tickLower = int24(bound(inputs.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        inputs.tickUpper = int24(bound(inputs.tickUpper, inputs.tickLower + 1, TickMath.MAX_TICK));
        inputs.liquidity = uint128(bound(inputs.liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, inputs.liquidity, users.liquidityProvider, inputs.tickLower, inputs.tickUpper, false
        );

        // And: Neither underlying exposure reaches its maximum and neither usd value overflows.
        {
            (uint256 amount0, uint256 amount1) = principalAmountsAtPrice(tokenId, sqrtPriceX96);
            vm.assume(amount0 < type(uint112).max);
            vm.assume(amount1 < type(uint112).max);
            inputs.initialExposure0 =
                uint112(bound(inputs.initialExposure0, 0, type(uint112).max - 1 - uint112(amount0)));
            inputs.initialExposure1 =
                uint112(bound(inputs.initialExposure1, 0, type(uint112).max - 1 - uint112(amount1)));
            inputs.maxExposure0 = uint112(
                bound(inputs.maxExposure0, uint112(amount0) + inputs.initialExposure0 + 1, type(uint112).max)
            );
            inputs.maxExposure1 = uint112(
                bound(inputs.maxExposure1, uint112(amount1) + inputs.initialExposure1 + 1, type(uint112).max)
            );
            vm.assume(amount0 + inputs.initialExposure0 <= type(uint256).max / inputs.priceToken0 / 1e18);
            vm.assume(amount1 + inputs.initialExposure1 <= type(uint256).max / inputs.priceToken1 / 1e18);
        }

        // And: Both underlying tokens are allowed assets with a trusted usd price.
        addAssetToArcadia(address(token0), int256(inputs.priceToken0), inputs.initialExposure0, inputs.maxExposure0);
        addAssetToArcadia(address(token1), int256(inputs.priceToken1), inputs.initialExposure1, inputs.maxExposure1);

        // And: The usd exposures of the protocol and of the upper asset stay within range.
        inputs.riskFactor = uint16(bound(inputs.riskFactor, 0, AssetValuationLib.ONE_4));
        {
            (uint256 usdExposureProtocol,,) =
                metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            inputs.maxUsdExposureProtocol =
                uint112(bound(inputs.maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
            inputs.exposureUpperAssetToAsset = bound(
                inputs.exposureUpperAssetToAsset,
                0,
                usdExposureProtocol == 0 ? type(uint256).max : type(uint256).max / usdExposureProtocol
            );
        }
        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), inputs.maxUsdExposureProtocol, inputs.riskFactor
        );

        // When: An indirect deposit of one position is processed.
        vm.prank(address(registry));
        (uint256 recursiveCalls,) = metadex03CLAM.processIndirectDeposit(
            address(creditorUsd), address(metadex03PositionManager), tokenId, inputs.exposureUpperAssetToAsset, 1
        );

        // Then: The deposit recursed over three Asset Modules.
        assertEq(recursiveCalls, 3);

        // And: The exposure to the position is one and both underlying exposures are increased.
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(metadex03PositionManager)));
            (uint256 lastExposureAsset,) = metadex03CLAM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);
            (uint256 amount0, uint256 amount1) = principalAmountsAtPrice(tokenId, sqrtPriceX96);
            assertEq(metadex03CLAM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, 0), amount0);
            assertEq(metadex03CLAM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, 1), amount1);
            (uint128 exposure,,,) =
                erc20AM.riskParams(address(creditorUsd), bytes32(abi.encodePacked(uint96(0), address(token0))));
            assertEq(exposure, amount0 + inputs.initialExposure0);
            (exposure,,,) =
                erc20AM.riskParams(address(creditorUsd), bytes32(abi.encodePacked(uint96(0), address(token1))));
            assertEq(exposure, amount1 + inputs.initialExposure1);
        }
    }

    function testFuzz_Success_processIndirectDeposit_DepositAmountZero_BeforeDeposit(ProcessInputs memory inputs)
        public
    {
        // Given: An initialised pool of the two underlying tokens, priced at the ratio of their usd prices.
        (inputs.priceToken0, inputs.priceToken1) = givenValidPrices(inputs.priceToken0, inputs.priceToken1);
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(inputs.priceToken0, inputs.priceToken1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, sqrtPriceX96, 300);

        // And: A valid liquidity position in that pool.
        inputs.tickLower = int24(bound(inputs.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        inputs.tickUpper = int24(bound(inputs.tickUpper, inputs.tickLower + 1, TickMath.MAX_TICK));
        inputs.liquidity = uint128(bound(inputs.liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, inputs.liquidity, users.liquidityProvider, inputs.tickLower, inputs.tickUpper, false
        );

        // And: Neither underlying exposure reaches its maximum and neither usd value overflows.
        {
            (uint256 amount0, uint256 amount1) = principalAmountsAtPrice(tokenId, sqrtPriceX96);
            vm.assume(amount0 < type(uint112).max);
            vm.assume(amount1 < type(uint112).max);
            inputs.initialExposure0 =
                uint112(bound(inputs.initialExposure0, 0, type(uint112).max - 1 - uint112(amount0)));
            inputs.initialExposure1 =
                uint112(bound(inputs.initialExposure1, 0, type(uint112).max - 1 - uint112(amount1)));
            inputs.maxExposure0 = uint112(
                bound(inputs.maxExposure0, uint112(amount0) + inputs.initialExposure0 + 1, type(uint112).max)
            );
            inputs.maxExposure1 = uint112(
                bound(inputs.maxExposure1, uint112(amount1) + inputs.initialExposure1 + 1, type(uint112).max)
            );
            vm.assume(amount0 + inputs.initialExposure0 <= type(uint256).max / inputs.priceToken0 / 1e18);
            vm.assume(amount1 + inputs.initialExposure1 <= type(uint256).max / inputs.priceToken1 / 1e18);
        }

        // And: Both underlying tokens are allowed assets with a trusted usd price.
        addAssetToArcadia(address(token0), int256(inputs.priceToken0), inputs.initialExposure0, inputs.maxExposure0);
        addAssetToArcadia(address(token1), int256(inputs.priceToken1), inputs.initialExposure1, inputs.maxExposure1);

        // And: The usd exposures of the protocol and of the upper asset stay within range.
        inputs.riskFactor = uint16(bound(inputs.riskFactor, 0, AssetValuationLib.ONE_4));
        {
            (uint256 usdExposureProtocol,,) =
                metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            inputs.maxUsdExposureProtocol =
                uint112(bound(inputs.maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
            inputs.exposureUpperAssetToAsset = bound(
                inputs.exposureUpperAssetToAsset,
                0,
                usdExposureProtocol == 0 ? type(uint256).max : type(uint256).max / usdExposureProtocol
            );
        }
        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), inputs.maxUsdExposureProtocol, inputs.riskFactor
        );

        // When: An indirect deposit of zero positions is processed.
        vm.prank(address(registry));
        (uint256 recursiveCalls,) = metadex03CLAM.processIndirectDeposit(
            address(creditorUsd), address(metadex03PositionManager), tokenId, inputs.exposureUpperAssetToAsset, 0
        );

        // Then: The deposit recursed over three Asset Modules.
        assertEq(recursiveCalls, 3);

        // And: The exposure to the position stays zero and neither underlying exposure changes.
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(metadex03PositionManager)));
            (uint256 lastExposureAsset,) = metadex03CLAM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 0);
            assertEq(metadex03CLAM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, 0), 0);
            assertEq(metadex03CLAM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, 1), 0);
            (uint128 exposure,,,) =
                erc20AM.riskParams(address(creditorUsd), bytes32(abi.encodePacked(uint96(0), address(token0))));
            assertEq(exposure, inputs.initialExposure0);
            (exposure,,,) =
                erc20AM.riskParams(address(creditorUsd), bytes32(abi.encodePacked(uint96(0), address(token1))));
            assertEq(exposure, inputs.initialExposure1);
        }
    }

    function testFuzz_Success_processIndirectDeposit_DepositAmountZero_AfterDeposit(ProcessInputs memory inputs)
        public
    {
        // Given: An initialised pool of the two underlying tokens, priced at the ratio of their usd prices.
        (inputs.priceToken0, inputs.priceToken1) = givenValidPrices(inputs.priceToken0, inputs.priceToken1);
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(inputs.priceToken0, inputs.priceToken1));
        pool = createPoolMetadex03CL(address(token0), address(token1), 1, sqrtPriceX96, 300);

        // And: A valid liquidity position that leaves the later increase room in the per-tick cap.
        inputs.tickLower = int24(bound(inputs.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        inputs.tickUpper = int24(bound(inputs.tickUpper, inputs.tickLower + 1, TickMath.MAX_TICK));
        inputs.liquidityIncrease = uint128(bound(inputs.liquidityIncrease, 1, pool.maxLiquidityPerTick() - 1));
        inputs.liquidity = uint128(bound(inputs.liquidity, 1, pool.maxLiquidityPerTick() - inputs.liquidityIncrease));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, inputs.liquidity, users.liquidityProvider, inputs.tickLower, inputs.tickUpper, false
        );

        // And: Neither underlying exposure reaches its maximum and neither usd value overflows.
        (uint256 amount0, uint256 amount1) = principalAmountsAtPrice(tokenId, sqrtPriceX96);
        vm.assume(amount0 < type(uint112).max);
        vm.assume(amount1 < type(uint112).max);
        inputs.initialExposure0 = uint112(bound(inputs.initialExposure0, 0, type(uint112).max - 1 - uint112(amount0)));
        inputs.initialExposure1 = uint112(bound(inputs.initialExposure1, 0, type(uint112).max - 1 - uint112(amount1)));
        inputs.maxExposure0 =
            uint112(bound(inputs.maxExposure0, uint112(amount0) + inputs.initialExposure0 + 1, type(uint112).max));
        inputs.maxExposure1 =
            uint112(bound(inputs.maxExposure1, uint112(amount1) + inputs.initialExposure1 + 1, type(uint112).max));
        vm.assume(amount0 + inputs.initialExposure0 <= type(uint256).max / inputs.priceToken0 / 1e18);
        vm.assume(amount1 + inputs.initialExposure1 <= type(uint256).max / inputs.priceToken1 / 1e18);

        // And: Both underlying tokens are allowed assets with a trusted usd price.
        addAssetToArcadia(address(token0), int256(inputs.priceToken0), inputs.initialExposure0, inputs.maxExposure0);
        addAssetToArcadia(address(token1), int256(inputs.priceToken1), inputs.initialExposure1, inputs.maxExposure1);

        // And: The usd exposures of the protocol and of the upper asset stay within range.
        inputs.riskFactor = uint16(bound(inputs.riskFactor, 0, AssetValuationLib.ONE_4));
        {
            (uint256 usdExposureProtocol,,) =
                metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            inputs.maxUsdExposureProtocol =
                uint112(bound(inputs.maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
            inputs.exposureUpperAssetToAsset = bound(
                inputs.exposureUpperAssetToAsset,
                0,
                usdExposureProtocol == 0 ? type(uint256).max : type(uint256).max / usdExposureProtocol
            );
        }
        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), inputs.maxUsdExposureProtocol, inputs.riskFactor
        );

        // And: The position is already deposited.
        vm.prank(address(registry));
        metadex03CLAM.processDirectDeposit(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);

        // And: The liquidity of the deposited position is increased.
        {
            (uint256 increase0, uint256 increase1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(inputs.tickLower),
                TickMath.getSqrtRatioAtTick(inputs.tickUpper),
                inputs.liquidityIncrease
            );
            increaseLiquidityMetadex03CL(pool, tokenId, increase0, increase1, false);
        }

        // When: An indirect deposit of zero positions is processed.
        vm.prank(address(registry));
        metadex03CLAM.processIndirectDeposit(
            address(creditorUsd), address(metadex03PositionManager), tokenId, inputs.exposureUpperAssetToAsset, 0
        );

        // Then: The exposure to the position is still one and both underlying exposures are unchanged.
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(metadex03PositionManager)));
            (uint256 lastExposureAsset,) = metadex03CLAM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);
            assertEq(metadex03CLAM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, 0), amount0);
            assertEq(metadex03CLAM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, 1), amount1);
            (uint128 exposure,,,) =
                erc20AM.riskParams(address(creditorUsd), bytes32(abi.encodePacked(uint96(0), address(token0))));
            assertEq(exposure, amount0 + inputs.initialExposure0);
            (exposure,,,) =
                erc20AM.riskParams(address(creditorUsd), bytes32(abi.encodePacked(uint96(0), address(token1))));
            assertEq(exposure, amount1 + inputs.initialExposure1);
        }
    }
}
