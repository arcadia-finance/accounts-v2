/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeStableAM_Fuzz_Test } from "./_AerodromeStableAM.fuzz.t.sol";

import { FixedPointMathLib, FullMath, ERC20Mock } from "../AerodromeVolatileAM/_AerodromeVolatileAM.fuzz.t.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { AerodromeVolatileAM } from "../../../../src/asset-modules/Aerodrome-Finance/AerodromeVolatileAM.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "AerodromeStableAM".
 */
contract GetUnderlyingAssetsAmounts_AerodromeStableAM_Fuzz_Test is AerodromeStableAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeStableAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_getUnderlyingAssetsAmounts_SupplyIsZero(TestVariables memory testVars) public {
        // Given : Valid state
        testVars = initAndSetValidStateInPoolFixture(testVars);

        // And : totalSupply is zero
        uint256 totalSupply = 0;
        stdstore.target(address(pool)).sig(pool.totalSupply.selector).checked_write(totalSupply);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
        underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

        // When : Calling getUnderlyingAssetsAmounts
        // Then : It should revert
        vm.expectRevert(AerodromeVolatileAM.ZeroSupply.selector);
        aeroStableAM.getUnderlyingAssetsAmounts(
            address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
        );
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_SupplyGreaterThan0_Stable(TestVariables memory testVars)
        public
    {
        // Given : Valid state
        testVars = initAndSetValidStateInPoolFixture(testVars);

        uint256 trustedReserve0;
        uint256 trustedReserve1;
        uint256 underlyingAssetsAmount0;
        uint256 underlyingAssetsAmount1;
        uint256 p0;
        uint256 p1;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), testVars.token0));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), testVars.token1));

            // And : Pool is added to the AM
            aeroFactoryMock.setPool(address(pool));
            aeroStableAM.addAsset(address(pool));

            // When : Calling getUnderlyingAssetsAmounts()
            (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            aeroStableAM.getUnderlyingAssetsAmounts(
                address(creditorUsd), assetKey, testVars.assetAmount, underlyingAssetKeys
            );

            underlyingAssetsAmount0 = underlyingAssetsAmounts[0];
            underlyingAssetsAmount1 = underlyingAssetsAmounts[1];

            uint256 k = getK(testVars.reserve0, testVars.reserve1, 10 ** testVars.decimals0, 10 ** testVars.decimals1);

            p0 = rateUnderlyingAssetsToUsd[0].assetValue;
            p1 = rateUnderlyingAssetsToUsd[1].assetValue;

            uint256 c = FullMath.mulDiv(k, p1, p0); // 18 decimals
            uint256 d = p0.mulDivUp(p0, 1e18) + p1.mulDivUp(p1, 1e18); // 18 decimals

            trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e18, c, d)));
            trustedReserve1 = FullMath.mulDiv(trustedReserve0, p0, p1);
            trustedReserve0 = trustedReserve0 / 10 ** (18 - testVars.decimals0);
            trustedReserve1 = trustedReserve1 / 10 ** (18 - testVars.decimals1);
        }

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmount0, trustedReserve0.mulDivDown(testVars.assetAmount, pool.totalSupply()));
        assertEq(underlyingAssetsAmount1, trustedReserve1.mulDivDown(testVars.assetAmount, pool.totalSupply()));

        (uint256 token0Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token0, 0, 1e18);
        (uint256 token1Value,,) = erc20AssetModule.getValue(address(creditorUsd), testVars.token1, 0, 1e18);

        assertEq(p0, token0Value);
        assertEq(p1, token1Value);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_TestFormulas_Stable() public {
        uint8 decimals0 = 18;
        uint8 decimals1 = 4;
        uint256 initReserve0 = 1_111_111_000 * 10 ** decimals0;
        uint256 initReserve1 = 1_111_111_000 * 10 ** decimals1;

        // Given : Deploy two tokens for the new Aerodrome tokenPair
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", decimals0);
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", decimals1);

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        uint256 reserve0_;
        uint256 reserve1_;
        {
            deployAerodromeStableFixture(address(token0), address(token1));

            // And : The tokens of the pool are added to the Arcadia protocol with price of 1
            addUnderlyingTokenToArcadia(address(token0), int256(10 ** decimals0));
            addUnderlyingTokenToArcadia(address(token1), int256(10 ** decimals1));

            deal(address(token0), address(pool), initReserve0);
            deal(address(token1), address(pool), initReserve1);

            // And : A first position is minted
            pool.mint(users.accountOwner);

            // And : Add the pool to the AM
            aeroFactoryMock.setPool(address(pool));
            aeroStableAM.addAsset(address(pool));

            (reserve0_, reserve1_,) = pool.getReserves();
            emit log_named_uint("k_init", getK(reserve0_, reserve1_, 10 ** decimals0, 10 ** decimals1));

            uint256 amount0In = 1_111_110_000 * 10 ** decimals0;
            uint256 amount1Out = pool.getAmountOut(amount0In, address(token0));
            emit log_named_uint("amount1 out", amount1Out);

            // And : We swap tokens (but do not change relative price)
            deal(address(token0), users.accountOwner, amount0In);
            vm.startPrank(users.accountOwner);
            token0.transfer(address(pool), amount0In);

            pool.swap(0, amount1Out, users.accountOwner, "");
            vm.stopPrank();

            emit log_named_uint("asset0 fees", token0.balanceOf(pool.poolFees()));
            emit log_named_uint("asset1 fees", token1.balanceOf(pool.poolFees()));
            emit log_named_uint("pool asset0 balance", token0.balanceOf(address(pool)));
            emit log_named_uint("pool asset1 balance", token1.balanceOf(address(pool)));
            emit log_named_uint("user asset1 balance received", token1.balanceOf(users.accountOwner));

            bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pool)));

            bytes32[] memory underlyingAssetKeys = new bytes32[](2);
            underlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(token0)));
            underlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(token1)));

            (, rateUnderlyingAssetsToUsd) =
                aeroStableAM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 100, underlyingAssetKeys);
        }

        (reserve0_, reserve1_,) = pool.getReserves();
        emit log_named_uint("untrusted 0", reserve0_);
        emit log_named_uint("untrusted 1", reserve1_);

        uint256 k = getK(reserve0_, reserve1_, 10 ** decimals0, 10 ** decimals1);
        emit log_named_uint("k_new", k);

        uint256 p0 = rateUnderlyingAssetsToUsd[0].assetValue;
        uint256 p1 = rateUnderlyingAssetsToUsd[1].assetValue;

        // Avoid stack too deep
        uint256 decimals0Stack = decimals0;
        uint256 decimals1Stack = decimals1;
        uint256 initReserve0Stack = initReserve0;
        uint256 initReserve1Stack = initReserve1;

        // r'0 = sqrt(p1 * sqrt((k * p1) / p0) / sqrt(p0 ** 2 + p1 ** 2))
        uint256 c = FullMath.mulDiv(k, p1, p0);
        uint256 d = p0.mulDivUp(p0, 1e18) + p1.mulDivUp(p1, 1e18);

        uint256 trustedReserve0 = FixedPointMathLib.sqrt(p1 * FixedPointMathLib.sqrt(FullMath.mulDiv(1e18, c, d)));

        // r1' = (r0' * p0) / p1
        uint256 trustedReserve1 = FullMath.mulDiv(trustedReserve0, p0, p1);

        trustedReserve0 = trustedReserve0 / (1e18 / 10 ** decimals0Stack);
        trustedReserve1 = trustedReserve1 / (1e18 / 10 ** decimals1Stack);

        emit log_named_uint("trusted0_", trustedReserve0);
        emit log_named_uint("trusted1_", trustedReserve1);

        assertApproxEqAbs(trustedReserve0, initReserve0Stack, (10 ** decimals0Stack) - 2);
        assertApproxEqAbs(trustedReserve1, initReserve1Stack, (10 ** decimals1Stack) - 2);
    }
}
