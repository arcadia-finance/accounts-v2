/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Factory_Fuzz_Test, FactoryErrors } from "./_Factory.fuzz.t.sol";

import { BadERC721TokenReceiver } from "../../utils/mocks/BadERC721TokenReceiver.sol";

/**
 * @notice Fuzz tests for the functions "safeTransferAccount" of contract "Factory".
 */
contract SafeTransferAccount_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_safeTransferAccount_InvalidRecipient(address sender) public {
        vm.prank(sender);
        vm.expectRevert(FactoryErrors.InvalidRecipient.selector);
        factory.safeTransferAccount(address(0));
    }

    function testFuzz_Revert_safeTransferAccount_NonAccount(address sender, address to) public {
        vm.assume(to != address(0));
        vm.assume(sender != address(proxyAccount));

        vm.prank(sender);
        vm.expectRevert(FactoryErrors.OnlyAccount.selector);
        factory.safeTransferAccount(to);
    }

    function testFuzz_Revert_safeTransferAccount_UnsafeRecipient() public {
        // Given: A contract without onERC721Received implemented.
        BadERC721TokenReceiver contract_ = new BadERC721TokenReceiver();

        // When: Account is transferred by the Account to the contract that does not have onERC721Received implemented.
        // Then: The transaction reverts with UnsafeRecipient
        vm.prank(address(proxyAccount));
        vm.expectRevert(FactoryErrors.UnsafeRecipient.selector);
        factory.safeTransferAccount(address(contract_));
    }

    function testFuzz_Success_safeTransferAccount(address to) public canReceiveERC721(to) {
        vm.assume(to != users.accountOwner);
        vm.assume(to != address(0));

        uint256 balanceOwnerBefore = factory.balanceOf(users.accountOwner);
        uint256 balanceToBefore = factory.balanceOf(to);
        uint256 id = factory.accountIndex(address(proxyAccount));

        vm.prank(address(proxyAccount));
        vm.expectEmit();
        emit Transfer(users.accountOwner, to, id);
        factory.safeTransferAccount(to);

        assertEq(factory.ownerOfAccount(address(proxyAccount)), to);
        assertEq(factory.balanceOf(users.accountOwner), balanceOwnerBefore - 1);
        assertEq(factory.balanceOf(to), balanceToBefore + 1);
    }
}
