/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, Constants } from "./_StargateAssetModule.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../src/asset-modules/Stargate-Finance/StargateAssetModule.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "StargateAssetModule".
 */
contract GetUnderlyingAssetsAmounts_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    using FixedPointMathLib for uint112;
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountGreaterThan0(
        uint96 positionId,
        uint112 assetAmount,
        uint128 totalLiquidity,
        uint256 convertRate,
        uint128 amountStaked,
        uint128 totalSupply,
        uint256 poolId,
        uint128 pendingEmissions
    ) public {
        // Given : convertRate should be between 1 and 10**18.
        convertRate = bound(convertRate, 0, 18);
        convertRate = 10 ** convertRate;
        emit log_uint(convertRate);

        // And : assetAmount is 1.
        assetAmount = 1;

        // And : pendingEmissions is smaller than type(uint128).max / 1e18
        pendingEmissions = uint128(bound(pendingEmissions, 0, type(uint128).max / 1e18));

        // And : totalStaked > 0, thus amountStaked > 0
        vm.assume(amountStaked > 0);

        // And : totalLiquidity should be at least equal to amountStaked (invariant)
        totalLiquidity = uint128(bound(totalLiquidity, amountStaked, type(uint128).max));

        // And : totalLiquidity should be >= totalSupply
        vm.assume(totalLiquidity >= totalSupply);

        // And : totalSupply is greater than 0
        vm.assume(totalSupply > 0);

        // And : Avoid overflow in calculations
        vm.assume(uint256(amountStaked) * totalLiquidity <= type(uint256).max / convertRate);

        // And : Set valid state on the pool.
        poolMock.setState(address(mockERC20.token1), totalLiquidity, totalSupply, convertRate);

        // And : Set valid state on lpStakingTime
        lpStakingTimeMock.setInfoForPoolId(poolId, pendingEmissions, address(poolMock));

        // And : Set valid state in AM
        stargateAssetModule.setAssetInPosition(address(poolMock), positionId);
        stargateAssetModule.setAmountStakedForPosition(positionId, amountStaked);

        stargateAssetModule.setTotalStakedForAsset(address(poolMock), amountStaked);

        stargateAssetModule.setAssetToPoolId(address(poolMock), poolId);
        stargateAssetModule.setAssetToConversionRate(address(poolMock), convertRate);

        // Avoid stack too deep
        uint96 positionIdStack = positionId;

        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);
        underlyingAssetKeys[1] = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule.REWARD_TOKEN()), 0);
        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        stargateAssetModule.getUnderlyingAssetsAmounts(
            address(creditorToken1), assetKey, assetAmount, underlyingAssetKeys
        );

        // Then : Asset amounts returned should be correct.
        uint256 computedUnderlyingAssetAmount = uint256(amountStaked).mulDivDown(totalLiquidity, totalSupply);
        computedUnderlyingAssetAmount *= convertRate;
        assertEq(underlyingAssetsAmounts[0], computedUnderlyingAssetAmount);
        assertEq(underlyingAssetsAmounts[1], stargateAssetModule.rewardOf(positionIdStack));

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_amountIsZero(uint96 positionId) public {
        bytes32[] memory underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);
        underlyingAssetKeys[1] = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule.REWARD_TOKEN()), 0);
        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), positionId);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stargateAssetModule.getUnderlyingAssetsAmounts(address(creditorToken1), assetKey, 0, underlyingAssetKeys);

        // Then : Values returned should be correct.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
