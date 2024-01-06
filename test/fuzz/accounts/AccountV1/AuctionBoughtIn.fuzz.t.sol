/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "auctionBoughtIn" of contract "AccountV1".
 */
contract AuctionBoughtIn_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
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
        accountExtension.setLocked(2);

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.auctionBoughtIn(recipient);
    }

    function testFuzz_Success_auctionBoughtIn(address recipient) public canReceiveERC721(recipient) {
        // Given: An Account.
        uint256 id = factory.accountIndex(address(accountExtension));

        // When: The Liquidator calls auctionBoughtIn.
        vm.prank(accountExtension.liquidator());
        accountExtension.auctionBoughtIn(recipient);

        // Then: Ownership of the Account is transferred to the recipient.
        assertEq(accountExtension.owner(), recipient);
        assertEq(factory.ownerOf(id), recipient);
    }
}
