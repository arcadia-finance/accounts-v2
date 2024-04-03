/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import {
    StakedAerodromeAM_IndirectEmissions_Fuzz_Test,
    StakedAerodromeAM_IndirectEmissions,
    StakingAM
} from "./_StakedAerodromeAM_IndirectEmissions.fuzz.t.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the "GetUnderlyingAssetsAmounts" function of contract "StakedAerodromeAM_IndirectEmissions".
 */
contract GetUnderlyingAssetsAmounts_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_IndirectEmissions_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_IndirectEmissions_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_GetUnderlyingAssetsAmounts_AmountIsZero(
        bytes32 assetKey,
        address creditor,
        bytes32[] memory underlyingAssetKeys
    ) public {
        // Given : amount is zero
        uint256 amount = 0;

        // When : Calling getUnderlyingAssetsAmounts
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakedAerodromeAM.getUnderlyingAssetsAmounts(creditor, assetKey, amount, underlyingAssetKeys);

        // Then : It should return an empty and a zero-value array
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
        assertEq(underlyingAssetsAmounts.length, 1);
        assertEq(underlyingAssetsAmounts[0], 0);
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts_AmountIsOne(
        uint128 amountStaked,
        uint96 positionId,
        address randomAddress,
        address creditor,
        bytes32[] memory underlyingAssetKeys
    ) public {
        // Given : Amount is 1
        uint256 amount = 1;
        // Given : An amount staked is set for a position
        stakedAerodromeAM.setAmountStakedForPosition(positionId, amountStaked);

        bytes32 assetKey = stakedAerodromeAM.getKeyFromAsset(randomAddress, positionId);

        // When : Calling getUnderlyingAssetsAmounts
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            stakedAerodromeAM.getUnderlyingAssetsAmounts(creditor, assetKey, amount, underlyingAssetKeys);

        // Then : It should return correct values
        assertEq(underlyingAssetsAmounts.length, 1);
        assertEq(underlyingAssetsAmounts[0], amountStaked);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
