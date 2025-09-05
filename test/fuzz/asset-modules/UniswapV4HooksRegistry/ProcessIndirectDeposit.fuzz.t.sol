/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { DefaultUniswapV4AM } from "../../../../src/asset-modules/UniswapV4/DefaultUniswapV4AM.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { UniswapV4HooksRegistry } from "../../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "UniswapV4HooksRegistry".
 */
contract ProcessIndirectDeposit_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();

        token0 = new ERC20Mock("Token 0", "TOK0", 18);
        token1 = new ERC20Mock("Token 1", "TOK1", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonRegistry(
        address unprivilegedAddress,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint256 exposureUpperAssetToAsset
    ) public {
        vm.assume(unprivilegedAddress != address(registry));

        // Given : Valid state
        (uint256 tokenId,,,) = givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        v4HooksRegistry.processIndirectDeposit(
            address(creditorUsd), address(positionManagerV4), tokenId, exposureUpperAssetToAsset, 1
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_BadDepositAmount(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint256 exposureUpperAssetToAsset,
        int256 amount
    ) public {
        // Given : Amount not equal to 0 or 1
        vm.assume(amount != 0);
        vm.assume(amount != 1);

        // And : Valid state
        (uint256 tokenId,,,) = givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // When : Calling processIndirectDeposit()
        // Then : It should revert
        vm.prank(address(registry));
        vm.expectRevert(DefaultUniswapV4AM.InvalidAmount.selector);
        v4HooksRegistry.processIndirectDeposit(
            address(creditorUsd), address(positionManagerV4), tokenId, exposureUpperAssetToAsset, amount
        );
    }

    function testFuzz_Success_processIndirectDeposit_DepositAmountOne(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given: Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // And:  exposure to underlying tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 < maxExposure0);
        vm.assume(amount1 + initialExposure1 < maxExposure1);

        // And: Usd value of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // And: Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniswapV4AM.getValue(address(creditorUsd), address(positionManagerV4), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100
        );

        {
            // When: Calling processIndirectDeposit()
            vm.prank(address(registry));
            (uint256 recursiveCalls,) =
                v4HooksRegistry.processIndirectDeposit(address(creditorUsd), address(positionManagerV4), tokenId, 0, 1);
            assertEq(recursiveCalls, 3);
        }

        {
            // Then: Exposure of the asset is one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManagerV4)));
            (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);

            // And: Exposures to the underlying assets are updated.
            // Token0:
            bytes32 underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                amount0
            );
            (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, amount0 + initialExposure0);
            // Token1:
            underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                amount1
            );
            (exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, amount1 + initialExposure1);
        }
    }

    function testFuzz_Success_processIndirectDeposit_DepositAmountZero_BeforeDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given : Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // Check that exposure to underlying tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 < maxExposure0);
        vm.assume(amount1 + initialExposure1 < maxExposure1);

        // And: Usd value of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniswapV4AM.getValue(address(creditorUsd), address(positionManagerV4), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100
        );

        {
            // When: processDirectDeposit is called with amount 0.
            vm.prank(address(registry));
            (uint256 recursiveCalls,) =
                v4HooksRegistry.processIndirectDeposit(address(creditorUsd), address(positionManagerV4), tokenId, 0, 0);

            // Then: Correct variables are returned.
            assertEq(recursiveCalls, 3);
        }

        {
            // And: Exposure of the asset is one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManagerV4)));
            (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 0);

            // And: Exposures to the underlying assets are updated.
            // Token0:
            bytes32 underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                0
            );
            (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, initialExposure0);
            // Token1:
            underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                0
            );
            (exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, initialExposure1);
        }
    }

    function testFuzz_Success_processIndirectDeposit_DepositAmountZero_AfterDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Given : Valid state
        (uint256 tokenId, uint256 amount0, uint256 amount1,) =
            givenValidPosition(liquidity, tickLower, tickUpper, priceToken0, priceToken1, 0);

        // Check that exposure to underlying tokens stays below maxExposures.
        vm.assume(amount0 + initialExposure0 < maxExposure0);
        vm.assume(amount1 + initialExposure1 < maxExposure1);

        // And: Usd exposure of underlying assets does not overflow.
        vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addAssetToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        // And: usd exposure to protocol below max usd exposure.
        (uint256 usdExposureProtocol,,) =
            uniswapV4AM.getValue(address(creditorUsd), address(positionManagerV4), tokenId, 1);
        vm.assume(usdExposureProtocol < type(uint112).max);
        maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));

        vm.prank(users.riskManager);
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100
        );

        // Given: uniV4 position is deposited.
        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManagerV4), tokenId, 1);

        {
            // When: processDirectDeposit is called with amount 0.
            vm.prank(address(registry));
            v4HooksRegistry.processIndirectDeposit(address(creditorUsd), address(positionManagerV4), tokenId, 0, 0);

            // Then: Exposure of the asset is still one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManagerV4)));
            (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);

            // And: Exposures to the underlying assets are of the old liquidity.
            // Token0:
            bytes32 underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                amount0
            );
            (uint128 exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, amount0 + initialExposure0);
            // Token1:
            underlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniswapV4AM.getExposureAssetToUnderlyingAssetsLast(address(creditorUsd), assetKey, underlyingAssetKey),
                amount1
            );
            (exposure,,,) = erc20AM.riskParams(address(creditorUsd), underlyingAssetKey);
            assertEq(exposure, amount1 + initialExposure1);
        }
    }
}
