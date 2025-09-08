/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";
import { AccountVariableVersion } from "../../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../../utils/Constants.sol";
import { Factory } from "../../../../src/Factory.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccount" of contract "AccountV4".
 */
contract UpgradeAccount_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();

        // Set the accountSpot version in the Factory.
        vm.startPrank(users.owner);
        accountLogic = new AccountV3(address(factory), address(accountsGuard), address(0));
        vm.stopPrank();
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
        account.upgradeAccount(newImplementation, newRegistry, newVersion, data);
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
        accountSpot.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Success_upgradeAccountVersion(uint32 time) public {
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof3To4;

        vm.warp(time);

        // When: "users.accountOwner" Upgrade the account to AccountV3Logic.
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit Factory.AccountUpgraded(address(accountSpot), 3);
        factory.upgradeAccountVersion(address(accountSpot), 3, proofs);
        vm.stopPrank();

        // And: The Account version is updated.
        assertEq(accountSpot.ACCOUNT_VERSION(), 3);

        // And: lastActionTimestamp is updated.
        assertEq(accountSpot.lastActionTimestamp(), time);

        // And: registry is valid
        assertEq(accountSpot.registry(), address(registry));
    }
}
