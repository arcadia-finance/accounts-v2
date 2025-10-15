/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV3 } from "../../../src/accounts/AccountV3.sol";
import { AccountV3Extension } from "../../utils/extensions/AccountV3Extension.sol";
import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";
import { FactoryErrors } from "../../../src/libraries/Errors.sol";

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

        AccountV3Extension account_ = new AccountV3Extension(address(factory), address(accountsGuard), address(0));
        coolDownPeriod = account_.getCoolDownPeriod();
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function coolDownPeriodPassed(address account_, uint32 lastActionTimestamp, uint32 timePassed) public {
        AccountV3 account__ = AccountV3(account_);
        timePassed = uint32(bound(timePassed, coolDownPeriod + 1, type(uint32).max));

        vm.warp(lastActionTimestamp);

        // Update the lastActionTimestamp.
        vm.prank(account__.owner());
        account__.withdraw(new address[](0), new uint256[](0), new uint256[](0));

        vm.warp(uint256(lastActionTimestamp) + timePassed);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_SFT1_ToZeroAddress(
        address owner,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(owner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(owner, address(0), newAccount);
    }

    function testFuzz_Revert_SFT1_ToAccount(address owner, uint32 salt, uint32 lastActionTimestamp, uint32 timePassed)
        public
    {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(owner);
        vm.expectRevert(FactoryErrors.InvalidRecipient.selector);
        factory.safeTransferFrom(owner, newAccount, newAccount);
    }

    function testFuzz_Revert_SFT1_CallerNotOwner(
        address owner,
        address caller,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != caller);
        vm.assume(caller != address(0));
        vm.assume(to != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(caller);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, to, newAccount);
    }

    function testFuzz_Revert_SFT2_ToZeroAddress(
        address owner,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(owner, address(0), latestId);
    }

    function testFuzz_Revert_SFT2_InvalidRecipient(
        address owner,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        vm.expectRevert(FactoryErrors.InvalidRecipient.selector);
        factory.safeTransferFrom(owner, newAccount, latestId);
    }

    function testFuzz_Revert_SFT2_CallerNotOwner(
        address owner,
        address caller,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != caller);
        vm.assume(caller != address(0));
        vm.assume(to != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(caller);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, to, latestId);
    }

    function testFuzz_Revert_SFT3_ToZeroAddress(
        address owner,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(owner, address(0), latestId, "");
    }

    function testFuzz_Revert_SFT3_ToAccount(address owner, uint32 salt, uint32 lastActionTimestamp, uint32 timePassed)
        public
    {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        vm.expectRevert(FactoryErrors.InvalidRecipient.selector);
        factory.safeTransferFrom(owner, newAccount, latestId, "");
    }

    function testFuzz_Revert_SFT3_CallerNotOwner(
        address owner,
        address caller,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != caller);
        vm.assume(caller != address(0));
        vm.assume(to != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(caller);
        vm.expectRevert("NOT_AUTHORIZED");
        factory.safeTransferFrom(owner, to, latestId, "");
    }

    function testFuzz_Revert_TransferFrom_ToZeroAddress(
        address owner,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        vm.expectRevert("INVALID_RECIPIENT");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        factory.transferFrom(owner, address(0), latestId);
    }

    function testFuzz_Revert_TransferFrom_ToAccount(
        address owner,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        vm.expectRevert(FactoryErrors.InvalidRecipient.selector);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        factory.transferFrom(owner, newAccount, latestId);
    }

    function testFuzz_Revert_TransferFrom_CallerNotOwner(
        address owner,
        address caller,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(owner != address(0));
        vm.assume(owner != caller);
        vm.assume(caller != address(0));
        vm.assume(to != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(caller);
        vm.expectRevert("NOT_AUTHORIZED");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        factory.transferFrom(owner, to, latestId);
    }

    function testFuzz_Success_STF1(
        address owner,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public canReceiveERC721(to) {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        vm.prank(owner);
        factory.safeTransferFrom(owner, to, newAccount);

        assertEq(factory.ownerOfAccount(newAccount), to);
    }

    function testFuzz_Success_SFT2(
        address owner,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public canReceiveERC721(to) {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        factory.safeTransferFrom(owner, to, latestId);

        assertEq(factory.ownerOfAccount(newAccount), to);
    }

    function testFuzz_Success_SFT3(
        address owner,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public canReceiveERC721(to) {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        factory.safeTransferFrom(owner, to, latestId, "");

        assertEq(factory.ownerOfAccount(newAccount), to);
    }

    function testFuzz_Success_TransferFrom(
        address owner,
        address to,
        uint32 salt,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public canReceiveERC721(to) {
        vm.assume(owner != address(0));

        vm.broadcast(owner);
        address newAccount = factory.createAccount(salt, 0, address(0));

        vm.assume(to != newAccount);

        coolDownPeriodPassed(newAccount, lastActionTimestamp, timePassed);

        uint256 latestId = factory.allAccountsLength();
        vm.prank(owner);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        factory.transferFrom(owner, to, latestId);

        assertEq(factory.ownerOfAccount(newAccount), to);
    }
}
