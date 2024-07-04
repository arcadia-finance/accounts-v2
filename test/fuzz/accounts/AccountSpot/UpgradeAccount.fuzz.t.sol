/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1 } from "../../../../src/accounts/AccountV1.sol";
import { AccountV2 } from "../../../utils/mocks/accounts/AccountV2.sol";
import { AccountSpot_Fuzz_Test } from "./_AccountSpot.fuzz.t.sol";
import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountVariableVersion } from "../../../utils/mocks/accounts/AccountVariableVersion.sol";
import { Constants } from "../../../utils/Constants.sol";
import { Factory } from "../../../../src/Factory.sol";
import { RegistryExtension } from "../../../utils/extensions/RegistryExtension.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccount" of contract "AccountSpot".
 */
contract UpgradeAccount_AccountSpot_Fuzz_Test is AccountSpot_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountSpot_Fuzz_Test.setUp();

        // Set the accountSpot version in the Factory.
        vm.startPrank(users.owner);
        accountV1Logic = new AccountV1(address(factory));
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
        accountSpot.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(address(factory));
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountSpot.upgradeAccount(newImplementation, newRegistry, newVersion, data);
        vm.stopPrank();
    }

    function testFuzz_Success_upgradeAccountVersion(uint32 time) public {
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof2To1;

        vm.warp(time);

        // When: "users.accountOwner" Upgrade the account to AccountV1Logic.
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit Factory.AccountUpgraded(address(accountSpot), 1);
        factory.upgradeAccountVersion(address(accountSpot), 1, proofs);
        vm.stopPrank();

        // And: The Account version is updated.
        assertEq(accountSpot.ACCOUNT_VERSION(), 1);

        // And: lastActionTimestamp is updated.
        assertEq(accountSpot.lastActionTimestamp(), time);

        // And: registry is valid
        assertEq(accountSpot.registry(), address(registry));
    }
}
