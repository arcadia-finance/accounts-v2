/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Constants } from "../../utils/Constants.sol";
import { Factory } from "../../../src/Factory.sol";
import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";
import { FactoryErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "upgradeAccountVersion" of contract "Factory".
 */
contract UpgradeAccountVersion_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
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
        vm.assume(version > factory.latestAccountVersion());

        vm.startPrank(users.accountOwner);
        vm.expectRevert(FactoryErrors.InvalidUpgrade.selector);
        factory.upgradeAccountVersion(address(account), version, proofs);
        vm.stopPrank();
    }

    function testFuzz_Success_upgradeAccountVersion() public {
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.PROOF_4_TO_3;

        // When: "users.accountOwner" Upgrade the account to Version 4.
        vm.startPrank(users.accountOwner);
        vm.expectEmit(address(factory));
        emit Factory.AccountUpgraded(address(account), 4);
        factory.upgradeAccountVersion(address(account), 4, proofs);
        vm.stopPrank();
    }
}
