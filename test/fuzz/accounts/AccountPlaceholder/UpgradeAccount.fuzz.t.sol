/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountPlaceholder_Fuzz_Test } from "./_AccountPlaceholder.fuzz.t.sol";
import { Factory } from "../../../../src/Factory.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccount" of contract "AccountPlaceholder".
 */
contract UpgradeAccount_AccountPlaceholder_Fuzz_Test is AccountPlaceholder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountPlaceholder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_upgradeAccount_NonFactory(
        address newImplementation,
        address newRegistry,
        uint256 newVersion,
        address nonFactory,
        bytes calldata data
    ) public {
        vm.assume(nonFactory != address(factory));

        // Should revert if not called by the Factory.
        vm.startPrank(nonFactory);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        account_.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccount_Reentered(
        address newImplementation,
        address newRegistry,
        uint256 newVersion,
        bytes calldata data
    ) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(address(factory));
        vm.expectRevert(AccountsGuard.Reentered.selector);
        account_.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_revert_upgradeAccountVersion_ToAccountPlaceholder(uint32 time) public {
        uint256 accountPlaceholderVersion = factory.latestAccountVersion();
        bytes32 root = keccak256(abi.encodePacked(account.ACCOUNT_VERSION(), accountPlaceholderVersion));
        factory.setVersionRoot(root);

        vm.warp(time);

        // When: "users.accountOwner" Upgrade the account to AccountPlaceholder.
        bytes32[] memory proofs = new bytes32[](0);
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidUpgrade.selector);
        factory.upgradeAccountVersion(address(account), accountPlaceholderVersion, proofs);
    }

    function testFuzz_Success_upgradeAccountVersion_ToVersion3(uint32 time) public {
        uint256 accountPlaceholderVersion = factory.latestAccountVersion();
        bytes32 root = keccak256(abi.encodePacked(accountPlaceholderVersion, uint256(3)));
        factory.setVersionRoot(root);

        vm.warp(time);

        // When: "users.accountOwner" Upgrade the account to AccountV3Logic.
        bytes32[] memory proofs = new bytes32[](0);
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit Factory.AccountUpgraded(address(account_), 3);
        factory.upgradeAccountVersion(address(account_), 3, proofs);
        vm.stopPrank();

        // And: The Account version is updated.
        assertEq(account_.ACCOUNT_VERSION(), 3);

        // And: lastActionTimestamp is updated.
        assertEq(account_.lastActionTimestamp(), time);

        // And: registry is valid.
        assertEq(account_.registry(), address(registry));

        // And: owner is the same.
        assertEq(account_.owner(), users.accountOwner);
    }

    function testFuzz_Success_upgradeAccountVersion_ToVersion4(uint32 time) public {
        uint256 accountPlaceholderVersion = factory.latestAccountVersion();
        bytes32 root = keccak256(abi.encodePacked(accountPlaceholderVersion, uint256(4)));
        factory.setVersionRoot(root);

        vm.warp(time);

        // When: "users.accountOwner" Upgrade the account to AccountV4Logic.
        bytes32[] memory proofs = new bytes32[](0);
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit Factory.AccountUpgraded(address(account_), 4);
        factory.upgradeAccountVersion(address(account_), 4, proofs);
        vm.stopPrank();

        // And: The Account version is updated.
        assertEq(account_.ACCOUNT_VERSION(), 4);

        // And: lastActionTimestamp is updated.
        assertEq(account_.lastActionTimestamp(), time);

        // And: registry is valid.
        assertEq(account_.registry(), address(registry));

        // And: owner is the same.
        assertEq(account_.owner(), users.accountOwner);
    }
}
