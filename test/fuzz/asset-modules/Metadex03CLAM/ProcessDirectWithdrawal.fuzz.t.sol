/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "processDirectWithdrawal" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ProcessDirectWithdrawal_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
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
    function testFuzz_Success_processDirectWithdrawal_WithdrawAmountOne(ProcessInputs memory inputs) public {
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

        // And: The usd exposure of the protocol stays below its maximum.
        inputs.riskFactor = uint16(bound(inputs.riskFactor, 0, AssetValuationLib.ONE_4));
        {
            (uint256 usdExposureProtocol,,) =
                metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            inputs.maxUsdExposureProtocol =
                uint112(bound(inputs.maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }
        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), inputs.maxUsdExposureProtocol, inputs.riskFactor
        );

        // And: The position is deposited.
        vm.prank(address(registry));
        metadex03CLAM.processDirectDeposit(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);

        // When: A direct withdrawal of one position is processed.
        vm.prank(address(registry));
        metadex03CLAM.processDirectWithdrawal(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);

        // Then: The stored liquidity of the position is deleted.
        assertEq(metadex03CLAM.getAssetToLiquidity(tokenId), 0);

        // And: The exposure to the position is zero and both underlying exposures are back to their initial value.
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

    function testFuzz_Success_processDirectWithdrawal_WithdrawAmountZero_BeforeDeposit(ProcessInputs memory inputs)
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

        // And: The usd exposure of the protocol stays below its maximum.
        inputs.riskFactor = uint16(bound(inputs.riskFactor, 0, AssetValuationLib.ONE_4));
        {
            (uint256 usdExposureProtocol,,) =
                metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            inputs.maxUsdExposureProtocol =
                uint112(bound(inputs.maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }
        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), inputs.maxUsdExposureProtocol, inputs.riskFactor
        );

        // When: A direct withdrawal of zero positions is processed.
        vm.prank(address(registry));
        metadex03CLAM.processDirectWithdrawal(address(creditorUsd), address(metadex03PositionManager), tokenId, 0);

        // Then: No liquidity is stored for the position.
        assertEq(metadex03CLAM.getAssetToLiquidity(tokenId), 0);

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

    function testFuzz_Success_processDirectWithdrawal_WithdrawAmountZero_AfterDeposit(ProcessInputs memory inputs)
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

        // And: The usd exposure of the protocol stays below its maximum.
        inputs.riskFactor = uint16(bound(inputs.riskFactor, 0, AssetValuationLib.ONE_4));
        {
            (uint256 usdExposureProtocol,,) =
                metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            inputs.maxUsdExposureProtocol =
                uint112(bound(inputs.maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }
        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), inputs.maxUsdExposureProtocol, inputs.riskFactor
        );

        // And: The position is deposited.
        vm.prank(address(registry));
        metadex03CLAM.processDirectDeposit(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);

        // When: A direct withdrawal of zero positions is processed.
        vm.prank(address(registry));
        metadex03CLAM.processDirectWithdrawal(address(creditorUsd), address(metadex03PositionManager), tokenId, 0);

        // Then: The liquidity stored at the time of the deposit is kept.
        (,,,,,,, uint128 mintedLiquidity,,,,) = metadex03PositionManager.positions(tokenId);
        assertEq(metadex03CLAM.getAssetToLiquidity(tokenId), mintedLiquidity);

        // And: The exposure to the position is still one and both underlying exposures are unchanged.
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
