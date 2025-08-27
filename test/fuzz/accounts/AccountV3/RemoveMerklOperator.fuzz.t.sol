/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { MerklFixture } from "../../../utils/fixtures/merkl/MerklFixture.f.sol";
import { OperatorMock } from "../../../utils/mocks/merkl/OperatorMock.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "removeMerklOperator" of contract "AccountV3".
 */
contract RemoveMerklOperator_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test, MerklFixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    OperatorMock internal operator;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV3_Fuzz_Test) {
        AccountV3_Fuzz_Test.setUp();

        // Deploy Merkl.
        deployMerkl(users.owner);

        // Deploy Account.
        accountExtension = new AccountV3Extension(address(factory), address(accountsGuard), address(distributor));

        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
            .checked_write(true);

        // Initiate Account (set owner and numeraire).
        vm.prank(address(factory));
        accountExtension.initialize(users.accountOwner, address(registry), address(creditorStable1));

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
        accountExtension.removeMerklOperator(operator_);
    }

    function testFuzz_Success_removeMerklOperator_StatusOffToOff() public {
        // Given : Operator is set to status "off".

        // When: accountOwner calls "removeMerklOperator" on the Account.
        vm.prank(users.accountOwner);
        accountExtension.removeMerklOperator(address(operator));

        // Then: Operator should be set to status "off".
        assertEq(distributor.operators(address(accountExtension), address(operator)), 0);
    }

    function testFuzz_Success_removeMerklOperator_StatusOnToOff() public {
        // Given : Operator is set to status "off".
        vm.prank(users.owner);
        distributor.toggleOperator(address(accountExtension), address(operator));

        // When: accountOwner calls "removeMerklOperator" on the Account.
        // Then: A call to the distributor should be made to toggle the operator status.
        vm.expectCall(
            address(distributor),
            abi.encodeWithSelector(distributor.toggleOperator.selector, address(accountExtension), address(operator))
        );
        vm.prank(users.accountOwner);
        accountExtension.removeMerklOperator(address(operator));

        // And: Operator should be set to status "off".
        assertEq(distributor.operators(address(accountExtension), address(operator)), 0);
    }
}
