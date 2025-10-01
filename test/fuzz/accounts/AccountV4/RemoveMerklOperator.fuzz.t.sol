/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV4 } from "../../../../src/accounts/AccountV4.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";
import { AccountV4Extension } from "../../../utils/extensions/AccountV4Extension.sol";
import { MerklFixture } from "../../../utils/fixtures/merkl/MerklFixture.f.sol";
import { OperatorMock } from "../../../utils/mocks/merkl/OperatorMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "removeMerklOperator" of contract "AccountV4".
 */
contract RemoveMerklOperator_AccountV4_Fuzz_Test is AccountV4_Fuzz_Test, MerklFixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountV4Extension internal account_;
    OperatorMock internal operator;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV4_Fuzz_Test) {
        AccountV4_Fuzz_Test.setUp();

        // Deploy Merkl.
        deployMerkl(users.owner);

        // Deploy Account.
        account_ = new AccountV4Extension(address(factory), address(accountsGuard), address(distributor));

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(account_)).checked_write(
            true
        );

        // Initiate Account (set owner and numeraire).
        vm.prank(address(factory));
        account_.initialize(users.accountOwner, address(registry), address(creditorStable1));

        // Deploy Operators.
        operator = new OperatorMock();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_removeMerklOperator_NonOwner(address operator_, address nonOwner) public {
        // Given: Non-owner is not the owner of the account.
        vm.assume(nonOwner != users.accountOwner);

        // When: Non-owner calls "removeMerklOperator" on the Account.
        // Then: Transaction should revert with AccountErrors.OnlyOwner.selector.
        vm.prank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        account_.removeMerklOperator(operator_);
    }

    function testFuzz_Revert_removeMerklOperator_Reentered(address operator_) public {
        // Given: Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        // When: accountOwner calls "removeMerklOperator" on the Account.
        // Then: Transaction should revert with AccountsGuard.Reentered.selector.
        vm.prank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        account_.removeMerklOperator(operator_);
    }

    function testFuzz_Success_removeMerklOperator_StatusOffToOff() public {
        // Given : Operator is set to status "off".

        // When: accountOwner calls "removeMerklOperator" on the Account.
        // Then: Correct event is emitted.
        vm.expectEmit(address(account_));
        emit AccountV4.MerklOperatorSet(address(operator), false);
        vm.prank(users.accountOwner);
        account_.removeMerklOperator(address(operator));

        // And: Operator should be set to status "off".
        assertEq(distributor.operators(address(account_), address(operator)), 0);
    }

    function testFuzz_Success_removeMerklOperator_StatusOnToOff() public {
        // Given : Operator is set to status "off".
        vm.prank(users.owner);
        distributor.toggleOperator(address(account_), address(operator));

        // When: accountOwner calls "removeMerklOperator" on the Account.
        // Then: A call to the distributor should be made to toggle the operator status.
        vm.expectCall(
            address(distributor),
            abi.encodeWithSelector(distributor.toggleOperator.selector, address(account_), address(operator))
        );
        // And: Correct event is emitted.
        vm.expectEmit(address(account_));
        emit AccountV4.MerklOperatorSet(address(operator), false);
        vm.prank(users.accountOwner);
        account_.removeMerklOperator(address(operator));

        // And: Operator should be set to status "off".
        assertEq(distributor.operators(address(account_), address(operator)), 0);
    }
}
