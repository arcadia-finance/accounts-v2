/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

import { AccountV1 } from "../../../src/accounts/AccountV1.sol";
import { AccountExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the functions "(safe)TransferFrom" of contract "Factory".
 */
contract TransferFrom_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint256 internal coolDownPeriod;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();

        AccountExtension account_ = new AccountExtension(address(factory));
        coolDownPeriod = account_.getCoolDownPeriod();
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    modifier notAccountOwner(address accountOwner) {
        vm.assume(accountOwner != address(0));
        vm.assume(accountOwner != users.accountOwner);
        _;
    }

    function coolDownPeriodPassed(address account, uint32 lastActionTimestamp, uint32 timePassed) public {
        AccountV1 account_ = AccountV1(account);
        timePassed = uint32(bound(timePassed, coolDownPeriod + 1, type(uint32).max));

        vm.warp(lastActionTimestamp);

        // Update the lastActionTimestamp.
        vm.prank(account_.owner());
        account_.withdraw(new address[](0), new uint256[](0), new uint256[](0));

        vm.warp(uint256(lastActionTimestamp) + timePassed);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_SFT1_InvalidRecipient(
        address newAccountOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(newAccountOwner, address(0), newAccount);
    }

    function testFuzz_Revert_SFT1_CallerNotOwner(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.safeTransferFrom(users.accountOwner, nonOwner, newAccount);
    }

    function testFuzz_Revert_SFT2_InvalidRecipient(
        address newAccountOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(newAccountOwner, address(0), latestId);
    }

    function testFuzz_Revert_SFT2_CallerNotOwner(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.safeTransferFrom(users.accountOwner, nonOwner, latestId);
    }

    function testFuzz_Revert_SFT3_InvalidRecipient(
        address newAccountOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(newAccountOwner, address(0), latestId, "");
    }

    function testFuzz_Revert_SFT3_CallerNotOwner(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.safeTransferFrom(users.accountOwner, nonOwner, latestId, "");
    }

    function testFuzz_Revert_TransferFrom_InvalidRecipient(
        address newAccountOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.transferFrom(newAccountOwner, address(0), latestId);
    }

    function testFuzz_Revert_TransferFrom_CallerNotOwner(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.transferFrom(users.accountOwner, nonOwner, latestId);
    }

    function testFuzz_Success_STF1(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) notTestContracts(nonOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(newAccountOwner);
        factory.safeTransferFrom(newAccountOwner, nonOwner, newAccount);
    }

    function testFuzz_Success_SFT2(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) notTestContracts(nonOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(newAccountOwner);
        factory.safeTransferFrom(newAccountOwner, nonOwner, newAccount);
    }

    function testFuzz_Success_SFT3(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) notTestContracts(nonOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        factory.safeTransferFrom(newAccountOwner, nonOwner, latestId, "");
    }

    function testFuzz_Success_TransferFrom(
        address newAccountOwner,
        address nonOwner,
        uint256 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public notAccountOwner(newAccountOwner) notTestContracts(nonOwner) {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        factory.transferFrom(newAccountOwner, nonOwner, latestId);
    }
}
