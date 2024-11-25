/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";

/**
 * @notice Fuzz tests for the function "processDirectWithdrawal" of contract "DefaultUniswapV4AM".
 */
contract ProcessDirectWithdrawal_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();

        token0 = new ERC20Mock("Token 0", "TOK0", 18);
        token1 = new ERC20Mock("Token 1", "TOK1", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonRegistry(
        address unprivilegedAddress,
        address creditor,
        address asset,
        uint256 assetId,
        uint256 amount
    ) public {
        vm.assume(unprivilegedAddress != address(v4HooksRegistry));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        uniswapV4AM.processDirectWithdrawal(creditor, asset, assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal_WithdrawAmountOne(
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
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100
        );

        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);

        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.processDirectWithdrawal(address(creditorUsd), address(positionManager), tokenId, 1);

        {
            // And: Exposure of the asset is zero.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManager)));
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

    function testFuzz_Success_processDirectWithdrawal_WithdrawAmountZero_BeforeDeposit(
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
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100
        );

        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.processDirectWithdrawal(address(creditorUsd), address(positionManager), tokenId, 0);

        {
            // And: Exposure of the asset is zero.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManager)));
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

    function testFuzz_Success_processDirectWithdrawal_WithdrawAmountZero_AfterDeposit(
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
                uniswapV4AM.getValue(address(creditorUsd), address(positionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), maxUsdExposureProtocol, 100
        );

        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.processDirectDeposit(address(creditorUsd), address(positionManager), tokenId, 1);

        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.processDirectWithdrawal(address(creditorUsd), address(positionManager), tokenId, 0);

        {
            // And: Exposure of the asset is one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(positionManager)));
            (uint256 lastExposureAsset,) = uniswapV4AM.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);

            // And : Exposures are unchanged
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
