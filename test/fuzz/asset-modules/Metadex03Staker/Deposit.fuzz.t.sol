/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03Staker } from "../../../../src/asset-modules/Metadex03/Metadex03Staker.sol";
import { Metadex03Staker_Fuzz_Test } from "./_Metadex03Staker.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "Metadex03Staker".
 */
contract Deposit_Metadex03Staker_Fuzz_Test is Metadex03Staker_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03Staker_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_deposit_OnlyAssetModule(address assetModule, address caller, address gauge, uint256 amount)
        public
    {
        // Given: A staker deployed by the Asset Module.
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();

        // And: The caller is not the Asset Module.
        vm.assume(caller != assetModule);

        // When: The caller deposits through the staker.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(Metadex03Staker.OnlyAssetModule.selector);
        staker.deposit(gauge, amount);
    }

    function testFuzz_Success_deposit(address assetModule, uint256 amount) public {
        // Given: A staker deployed and initialized by a non-zero Asset Module.
        vm.assume(assetModule != address(0));
        vm.prank(assetModule);
        Metadex03Staker staker = new Metadex03Staker();
        vm.prank(assetModule);
        staker.initialize(address(metadex03Gauge), address(metadex03Pool));

        // And: The staker holds a non-zero LP balance.
        amount = bound(amount, 1, type(uint256).max);
        deal(address(metadex03Pool), address(staker), amount);

        // When: The Asset Module deposits the amount through the staker.
        vm.prank(assetModule);
        staker.deposit(address(metadex03Gauge), amount);

        // Then: The amount is staked in the gauge, credited to the staker.
        assertEq(metadex03Gauge.balanceOf(address(staker)), amount);
        assertEq(metadex03Gauge.depositBlock(address(staker)), block.number);
        assertEq(metadex03Pool.balanceOf(address(staker)), 0);

        // And: The max allowance of the gauge is not decremented.
        assertEq(metadex03Pool.allowance(address(staker), address(metadex03Gauge)), type(uint256).max);
    }
}
