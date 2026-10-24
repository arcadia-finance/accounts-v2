/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { Metadex03Staker } from "../../../../src/asset-modules/Metadex03/Metadex03Staker.sol";
import { Metadex03Staker_Fuzz_Test } from "./_Metadex03Staker.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "emergencyWithdraw" of contract "Metadex03Staker".
 */
contract EmergencyWithdraw_Metadex03Staker_Fuzz_Test is Metadex03Staker_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03Staker_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_emergencyWithdraw_OnlyAssetModule(
        address assetModule,
        address caller,
        address gauge,
        address asset,
        uint256 amount
    ) public {
        // Given: A staker deployed by the Asset Module.
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();

        // And: The caller is not the Asset Module.
        vm.assume(caller != assetModule);

        // When: The caller withdraws through the staker.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(Metadex03Staker.OnlyAssetModule.selector);
        staker.emergencyWithdraw(gauge, asset, amount);
    }

    function testFuzz_Revert_emergencyWithdraw_EmergencyWithdrawDisabled(
        address assetModule,
        uint256 staked,
        uint256 amount
    ) public {
        // Given: A staker deployed and initialized by a non-zero Asset Module.
        vm.assume(assetModule != address(0));
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();
        vm.prank(assetModule);
        staker.initialize(address(metadex03Gauge), address(metadex03Pool));

        // And: The staker staked a non-zero LP balance in the gauge.
        staked = bound(staked, 1, type(uint256).max);
        deal(address(metadex03Pool), address(staker), staked);
        vm.prank(assetModule);
        staker.deposit(address(metadex03Gauge), staked);

        // And: The amount withdrawn is non-zero and not above the stake.
        amount = bound(amount, 1, staked);

        // And: The gauge factory disables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(false);

        // When: The Asset Module withdraws through the staker.
        // Then: It reverts.
        vm.prank(assetModule);
        vm.expectRevert(IMetadex03V2Gauge.EmergencyWithdrawDisabled.selector);
        staker.emergencyWithdraw(address(metadex03Gauge), address(metadex03Pool), amount);
    }

    function testFuzz_Success_emergencyWithdraw(address assetModule, uint256 staked, uint256 amount) public {
        // Given: A staker deployed and initialized by a non-zero Asset Module, not the gauge.
        vm.assume(assetModule != address(0));
        vm.assume(assetModule != address(metadex03Gauge));
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();
        vm.prank(assetModule);
        staker.initialize(address(metadex03Gauge), address(metadex03Pool));

        // And: The staker staked a non-zero LP balance in the gauge.
        staked = bound(staked, 1, type(uint256).max);
        deal(address(metadex03Pool), address(staker), staked);
        vm.prank(assetModule);
        staker.deposit(address(metadex03Gauge), staked);

        // And: The amount withdrawn is non-zero and not above the stake.
        amount = bound(amount, 1, staked);

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // When: The Asset Module withdraws the amount through the staker.
        vm.prank(assetModule);
        staker.emergencyWithdraw(address(metadex03Gauge), address(metadex03Pool), amount);

        // Then: The amount is unstaked from the gauge.
        assertEq(metadex03Gauge.balanceOf(address(staker)), staked - amount);
        assertEq(metadex03Gauge.totalSupply(), staked - amount);

        // And: The amount is forwarded to the Asset Module.
        assertEq(metadex03Pool.balanceOf(assetModule), amount);
        assertEq(metadex03Pool.balanceOf(address(staker)), 0);
    }
}
