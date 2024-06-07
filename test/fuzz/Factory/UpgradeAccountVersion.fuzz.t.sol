/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test, FactoryErrors } from "./_Factory.fuzz.t.sol";

import { AccountV2 } from "../../utils/mocks/accounts/AccountV2.sol";
import { Constants } from "../../utils/Constants.sol";
import { Factory } from "../../../src/Factory.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccountVersion" of contract "Factory".
 */
contract UpgradeAccountVersion_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV2 internal accountV2Logic;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();

        // Set a Mocked V2 Account Logic contract in the Factory.
        vm.startPrank(users.owner);
        accountV2Logic = new AccountV2(address(factory));
        factory.setNewAccountInfo(address(registry), address(accountV2Logic), Constants.upgradeRoot1To2, "");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_upgradeAccountVersion_NonOwner(
        address nonOwner,
        uint256 version,
        bytes32[] calldata proofs
    ) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert(FactoryErrors.OnlyAccountOwner.selector);
        factory.upgradeAccountVersion(address(account), version, proofs);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccountVersion_BlockedVersion(bytes32[] calldata proofs) public {
        vm.prank(users.owner);
        factory.blockAccountVersion(2);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(FactoryErrors.AccountVersionBlocked.selector);
        factory.upgradeAccountVersion(address(account), 2, proofs);
        vm.stopPrank();
    }

    function testFuzz_Revert_upgradeAccountVersion_VersionNotAllowed(uint256 version, bytes32[] calldata proofs)
        public
    {
        vm.assume(version != 1);
        vm.assume(version != 2);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(FactoryErrors.InvalidUpgrade.selector);
        factory.upgradeAccountVersion(address(account), version, proofs);
        vm.stopPrank();
    }

    function testFuzz_Success_upgradeAccountVersion() public {
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        // When: "users.accountOwner" Upgrade the account to AccountV2Logic.
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit Factory.AccountUpgraded(address(account), 2);
        factory.upgradeAccountVersion(address(account), factory.latestAccountVersion(), proofs);
        vm.stopPrank();
    }
}
