/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test, Constants } from "./_StargateAM.fuzz.t.sol";

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "StargateAM".
 */
contract GetUnderlyingAssetsAmounts_StargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssetsAmounts(
        uint112 assetAmount,
        uint128 totalLiquidity,
        uint256 convertRate,
        uint128 totalSupply,
        uint256 poolId
    ) public {
        // Given : convertRate should be between 1 and 10**18.
        convertRate = bound(convertRate, 0, 18);
        convertRate = 10 ** convertRate;

        // And : totalSupply is greater than 0
        totalSupply = uint128(bound(totalSupply, 1, type(uint128).max));

        // And : Avoid overflow in calculations
        if (totalLiquidity > 0) {
            assetAmount = uint112(bound(assetAmount, 0, type(uint256).max / convertRate / totalLiquidity));
        }

        // And: pool is added
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setState(address(mockERC20.token1), totalLiquidity, totalSupply, convertRate);
        stargateAssetModule.addAsset(poolId);

        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] = stargateAssetModule.getKeyFromAsset(address(mockERC20.token1), 0);
        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(poolMock), 0);

        // When : Calling getUnderlyingAssetsAmounts.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
        stargateAssetModule.getUnderlyingAssetsAmounts(
            address(creditorToken1), assetKey, assetAmount, underlyingAssetKeys
        );

        // Then : Asset amounts returned should be correct.
        uint256 computedUnderlyingAssetAmount = uint256(assetAmount) * totalLiquidity / totalSupply;
        computedUnderlyingAssetAmount *= convertRate;
        assertEq(underlyingAssetsAmounts[0], computedUnderlyingAssetAmount);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
