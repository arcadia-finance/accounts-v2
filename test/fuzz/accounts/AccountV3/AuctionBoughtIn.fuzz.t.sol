/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3, AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "auctionBoughtIn" of contract "AccountV3".
 */
contract AuctionBoughtIn_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_auctionBoughtIn_nonLiquidator(address nonLiquidator, address recipient) public {
        vm.assume(nonLiquidator != accountExtension.liquidator());

        vm.prank(nonLiquidator);
        vm.expectRevert(AccountErrors.OnlyLiquidator.selector);
        accountExtension.auctionBoughtIn(recipient);
    }

    function testFuzz_Revert_auctionBoughtIn_Reentered(address recipient) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountExtension.auctionBoughtIn(recipient);
    }

    function testFuzz_Success_auctionBoughtIn(address recipient) public canReceiveERC721(recipient) {
        // Given: An Account.
        uint256 id = factory.accountIndex(address(accountExtension));

        // And: recipient is not the account itself.
        vm.assume(recipient != address(accountExtension));

        // When: The Liquidator calls auctionBoughtIn.
        vm.prank(accountExtension.liquidator());
        accountExtension.auctionBoughtIn(recipient);

        // Then: Ownership of the Account is transferred to the recipient.
        assertEq(accountExtension.owner(), recipient);
        assertEq(factory.ownerOf(id), recipient);
    }
}
