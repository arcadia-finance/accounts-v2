/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { CreditorMock } from "../../../utils/mocks/creditors/CreditorMock.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "AccountV3".
 */
contract CloseMarginAccount_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_closeMarginAccount_NonOwner(address nonOwner) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        account.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeMarginAccount_Reentered() public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountExtension.closeMarginAccount();
    }

    function testFuzz_Revert_closeMarginAccount_NotDuringAuction() public {
        // Set "inAuction" to true.
        accountExtension.setInAuction();

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeMarginAccount_NonSetMarginAccount() public {
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.CreditorNotSet.selector);
        account.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeMarginAccount_OpenPosition(uint256 debt_) public {
        vm.prank(users.accountOwner);
        account.openMarginAccount(address(creditorStable1));

        // Mock debt.
        vm.assume(debt_ > 0);
        creditorStable1.setOpenPosition(address(account), debt_);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(CreditorMock.OpenPositionNonZero.selector);
        account.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Success_closeMarginAccount(uint112 exposure) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        exposure = uint112(bound(exposure, 0, type(uint112).max - 1));

        // And: The account has a different Creditor set.
        vm.prank(users.accountOwner);
        account.openMarginAccount(address(creditorStable1));

        // And: The account has assets deposited.
        depositERC20InAccount(account, mockERC20.stable1, exposure);

        // Assert creditor has exposure.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint128 actualExposure,,,) = erc20AM.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, exposure);

        // When: Margin account is closed.
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AccountV3.MarginAccountChanged(address(0), address(0));
        account.closeMarginAccount();
        vm.stopPrank();

        // Then: No creditor has been set and other variables updated
        assertTrue(account.creditor() == address(0));
        assertTrue(account.liquidator() == address(0));
        assertEq(account.minimumMargin(), 0);

        // And: Numeraire is still set.
        assertEq(account.numeraire(), address(mockERC20.stable1));

        // Exposure from Creditor is updated.
        (actualExposure,,,) = erc20AM.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, 0);
    }
}
