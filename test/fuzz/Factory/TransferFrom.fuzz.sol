/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the functions "(safe)TransferFrom" of contract "Factory".
 */
contract TransferFrom_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    modifier notAccountOwner(address accountOwner) {
        vm.assume(accountOwner != users.accountOwner);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_SFT1_InvalidRecipient(address newAccountOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0), address(0));

        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(newAccountOwner, address(0), newAccount);
    }

    function testFuzz_Revert_SFT1_CallerNotOwner(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0), address(0));

        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.safeTransferFrom(users.accountOwner, nonOwner, newAccount);
    }

    function testFuzz_Revert_SFT2_InvalidRecipient(address newAccountOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(newAccountOwner, address(0), latestId);
    }

    function testFuzz_Revert_SFT2_CallerNotOwner(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.safeTransferFrom(users.accountOwner, nonOwner, latestId);
    }

    function testFuzz_Revert_SFT3_InvalidRecipient(address newAccountOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.safeTransferFrom(newAccountOwner, address(0), latestId, "");
    }

    function testFuzz_Revert_SFT3_CallerNotOwner(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.safeTransferFrom(users.accountOwner, nonOwner, latestId, "");
    }

    function testFuzz_Revert_TransferFrom_InvalidRecipient(address newAccountOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        vm.expectRevert("INVALID_RECIPIENT");
        factory.transferFrom(newAccountOwner, address(0), latestId);
    }

    function testFuzz_Revert_TransferFrom_CallerNotOwner(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(nonOwner);
        vm.expectRevert("WRONG_FROM");
        factory.transferFrom(users.accountOwner, nonOwner, latestId);
    }

    function testFuzz_Success_STF1(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0), address(0));

        vm.prank(newAccountOwner);
        factory.safeTransferFrom(newAccountOwner, nonOwner, newAccount);
    }

    function testFuzz_Success_SFT2(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        address newAccount = factory.createAccount(salt, 0, address(0), address(0));

        vm.prank(newAccountOwner);
        factory.safeTransferFrom(newAccountOwner, nonOwner, newAccount);
    }

    function testFuzz_Success_SFT3(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        factory.safeTransferFrom(newAccountOwner, nonOwner, latestId, "");
    }

    function testFuzz_Success_TransferFrom(address newAccountOwner, address nonOwner, uint256 salt)
        public
        notAccountOwner(newAccountOwner)
    {
        vm.broadcast(newAccountOwner);
        factory.createAccount(salt, 0, address(0), address(0));

        uint256 latestId = factory.allAccountsLength();
        vm.prank(newAccountOwner);
        factory.transferFrom(newAccountOwner, nonOwner, latestId);
    }
}
