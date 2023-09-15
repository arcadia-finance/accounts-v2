/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "upgradeAccountVersion" of contract "Factory".
 */
contract UpgradeAccountVersion_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();

        // Set a Mocked V2 Account Logic contract in the Factory.
        vm.prank(users.creatorAddress);
        factory.setNewAccountInfo(
            address(mainRegistryExtension), address(accountV2Logic), Constants.upgradeRoot1To2, ""
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_upgradeAccountVersion_NonOwner(address nonOwner, uint16 version, bytes32[] calldata proofs)
        public
    {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("FTRY_UVV: Only Owner");
        factory.upgradeAccountVersion(address(proxyAccount), version, proofs);
        vm.stopPrank();
    }

    function testRevert_upgradeVaultVersion_BlockedVersion(bytes32[] calldata proofs) public {
        vm.prank(users.creatorAddress);
        factory.blockAccountVersion(2);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("FTRY_UVV: Account version blocked");
        factory.upgradeAccountVersion(address(proxyAccount), 2, proofs);
        vm.stopPrank();
    }

    function testRevert_upgradeVaultVersion_VersionNotAllowed(uint16 version, bytes32[] calldata proofs) public {
        vm.assume(version != 1);
        vm.assume(version != 2);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("FTR_UVV: Version not allowed");
        factory.upgradeAccountVersion(address(proxyAccount), version, proofs);
        vm.stopPrank();
    }

    function testSuccess_upgradeVaultVersion() public {
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = Constants.upgradeProof1To2;

        // When: "users.accountOwner" Upgrade the account to AccountV2Logic.
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AccountUpgraded(address(proxyAccount), 1, 2);
        factory.upgradeAccountVersion(address(proxyAccount), factory.latestAccountVersion(), proofs);
        vm.stopPrank();
    }
}
