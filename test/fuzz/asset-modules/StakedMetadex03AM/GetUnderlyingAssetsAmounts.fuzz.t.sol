/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "StakedMetadex03AM".
 */
contract GetUnderlyingAssetsAmounts_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getUnderlyingAssetsAmounts_ZeroAmount(bytes32 assetKey) public view {
        // Given: An arbitrary asset key, for which the Asset Module holds no position.

        // When: Calling getUnderlyingAssetsAmounts() for a zero amount.
        (uint256[] memory underlyingAssetsAmounts,) =
            stakedMetadex03AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 0, new bytes32[](2));

        // Then: Both legs are zero, and the array keeps its length.
        assertEq(underlyingAssetsAmounts.length, 2);
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
    }

    // forge-lint: disable-next-item(unsafe-typecast)
    function testFuzz_Success_getUnderlyingAssetsAmounts_ZeroAmount_StakedPosition(uint128 amount) public {
        // Given: A position with a non-zero staked amount.
        amount = uint128(bound(amount, 1, type(uint128).max));
        uint256 positionId = _initPositionWithEarned(amount, 0);

        // When: Calling getUnderlyingAssetsAmounts() for a zero amount of the position.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(positionId), address(stakedMetadex03AM)));
        (uint256[] memory underlyingAssetsAmounts,) =
            stakedMetadex03AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 0, new bytes32[](2));

        // Then: Both legs are zero, the staked amount of the position is not valued.
        assertEq(underlyingAssetsAmounts.length, 2);
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_RewardsNotValued(uint128 amount, uint256 emissions) public {
        // Given: A position whose emissions survive the gauge's and the Asset Module's per-1e18 flooring.
        vm.assume(amount != 0);
        emissions = bound(emissions, amount, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        assertGt(stakedMetadex03AM.rewardOf(positionId), 0);

        // When: Calling getUnderlyingAssetsAmounts().
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(positionId), address(stakedMetadex03AM)));
        (uint256[] memory underlyingAssetsAmounts,) =
            stakedMetadex03AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](2));

        // Then: The staked amount is valued, the rewards are not.
        assertEq(underlyingAssetsAmounts[0], amount);
        assertEq(underlyingAssetsAmounts[1], 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Metadex03Reverts(uint128 amount, uint256 emissions) public {
        // Given: A position with earned emissions.
        vm.assume(amount != 0);
        emissions = bound(emissions, 0, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);

        // And: Every Metadex03 contract of the position reverts on every call.
        vm.mockCallRevert(address(metadex03Gauge), bytes(""), bytes(""));
        vm.mockCallRevert(stakedMetadex03AM.getStaker(positionId), bytes(""), bytes(""));
        vm.mockCallRevert(address(metadex03GaugeFactory), bytes(""), bytes(""));
        vm.mockCallRevert(address(metadex03StableGaugeFactory), bytes(""), bytes(""));
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));
        vm.mockCallRevert(emissionsHandler, bytes(""), bytes(""));
        vm.mockCallRevert(address(factoryRegistryMetadex03), bytes(""), bytes(""));
        vm.mockCallRevert(address(metadex03Pool), bytes(""), bytes(""));
        vm.mockCallRevert(address(rewardToken), bytes(""), bytes(""));

        // When: Calling getUnderlyingAssetsAmounts().
        // forge-lint: disable-next-item(unsafe-typecast)
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(positionId), address(stakedMetadex03AM)));
        (uint256[] memory underlyingAssetsAmounts,) =
            stakedMetadex03AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](2));

        // Then: The staked amount is valued without any call to Metadex03, so the position stays liquidatable.
        assertEq(underlyingAssetsAmounts[0], amount);
        assertEq(underlyingAssetsAmounts[1], 0);
    }
}
