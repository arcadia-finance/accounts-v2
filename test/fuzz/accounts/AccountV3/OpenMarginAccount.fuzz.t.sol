/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";
import { AccountV3Extension } from "../../../utils/extensions/AccountV3Extension.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";
import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "openMarginAccount" of contract "AccountV3".
 */
contract OpenMarginAccount_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_openMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        account.openMarginAccount(address(creditorStable1));
    }

    function testFuzz_Revert_openeMarginAccount_Reentered() public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountExtension.openMarginAccount(address(creditorStable1));
        vm.stopPrank();
    }

    function testFuzz_Revert_openeMarginAccount_NotDuringAuction() public {
        // Set "inAuction" to true.
        accountExtension.setInAuction();

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.openMarginAccount(address(creditorStable1));
        vm.stopPrank();
    }

    function testFuzz_Revert_openMarginAccount_AlreadySet() public {
        // Open a margin account => will set a creditor
        vm.startPrank(users.accountOwner);
        account.openMarginAccount(address(creditorStable1));

        // Should revert if the creditor is already set
        vm.expectRevert(AccountErrors.CreditorAlreadySet.selector);
        account.openMarginAccount(address(creditorStable1));
    }

    function testFuzz_Revert_openMarginAccount_ExposureNotInLimits(uint112 exposure, uint112 maxExposure) public {
        // Given: "exposure" is equal or bigger than "maxExposure".
        exposure = uint112(bound(exposure, 1, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, 0, exposure));

        // And: MaxExposure is set for both creditors.
        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC20.stable1), 0, type(uint112).max, 0, 0
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );
        vm.stopPrank();

        // And: The account has a different Creditor set.
        vm.prank(users.accountOwner);
        account.openMarginAccount(address(creditorUsd));

        // And: The account has assets deposited.
        depositERC20InAccount(account, mockERC20.stable1, exposure);

        // Assert old creditor has been set.
        assertEq(account.creditor(), address(creditorUsd));
        assertEq(account.liquidator(), address(0));
        assertEq(account.minimumMargin(), 0);
        assertEq(account.numeraire(), address(0)); // USD

        // Assert old creditor has exposure.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint128 actualExposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, exposure);

        // When: Open a margin account with a new creditor.
        // Then: Should revert if the creditor is already set
        vm.prank(users.accountOwner);
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        account.openMarginAccount(address(creditorStable1));
    }

    function testFuzz_Revert_openMarginAccount_InvalidAccountVersion() public {
        // set a different Account version on the creditor
        creditorStable1.setCallResult(false);
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidAccountVersion.selector);
        account.openMarginAccount((address(creditorStable1)));
        vm.stopPrank();
    }

    function testFuzz_Success_openMarginAccount_FromNoCreditor(uint112 exposure, uint112 maxExposure, uint32 time)
        public
    {
        // Given: "exposure" is strictly smaller than "maxExposure".
        exposure = uint112(bound(exposure, 0, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, exposure + 1, type(uint112).max));

        // And: MaxExposure is set for creditor.
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );

        // And: The account has assets deposited.
        depositERC20InAccount(account, mockERC20.stable1, exposure);

        // Assert no creditor has been set on deployment
        assertEq(account.creditor(), address(0));
        // Assert no liquidator, numeraire and liquidation costs have been defined on deployment
        assertEq(account.liquidator(), address(0));
        assertEq(account.minimumMargin(), 0);
        assertEq(account.numeraire(), address(0));

        vm.warp(time);

        // Open a margin account
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit AccountV3.MarginAccountChanged(address(creditorStable1), Constants.initLiquidator);
        account.openMarginAccount(address(creditorStable1));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(account.creditor(), address(creditorStable1));
        assertEq(account.liquidator(), Constants.initLiquidator);
        assertEq(account.minimumMargin(), Constants.initLiquidationCost);
        assertEq(account.numeraire(), address(mockERC20.stable1));
        assertEq(account.lastActionTimestamp(), time);

        // And: the exposure of the Creditors is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint128 actualExposure,,,) = erc20AM.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, exposure);
    }

    function testFuzz_Success_openMarginAccount_FromDifferentCreditor(
        uint112 exposure,
        uint112 maxExposure,
        uint32 time
    ) public {
        // Given: "exposure" is strictly smaller than "maxExposure".
        exposure = uint112(bound(exposure, 0, type(uint112).max - 1));
        maxExposure = uint112(bound(maxExposure, exposure + 1, type(uint112).max));

        // And: MaxExposure is set for both creditors.
        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC20.stable1), 0, maxExposure, 0, 0);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC20.stable1), 0, maxExposure, 0, 0
        );
        vm.stopPrank();

        // And: The account has a different Creditor set.
        vm.prank(users.accountOwner);
        account.openMarginAccount(address(creditorUsd));

        // And: The account has assets deposited.
        depositERC20InAccount(account, mockERC20.stable1, exposure);

        // Assert old creditor has been set.
        assertEq(account.creditor(), address(creditorUsd));
        assertEq(account.liquidator(), address(0));
        assertEq(account.minimumMargin(), 0);
        assertEq(account.numeraire(), address(0)); // USD

        // Assert old creditor has exposure.
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC20.stable1)));
        (uint128 actualExposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, exposure);

        vm.warp(time);

        // When: Open a margin account with a new creditor.
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit AccountV3.MarginAccountChanged(address(creditorStable1), Constants.initLiquidator);
        account.openMarginAccount(address(creditorStable1));
        vm.stopPrank();

        // Then: A creditor has been set and other variables updated
        assertEq(account.creditor(), address(creditorStable1));
        assertEq(account.liquidator(), Constants.initLiquidator);
        assertEq(account.minimumMargin(), Constants.initLiquidationCost);
        assertEq(account.numeraire(), address(mockERC20.stable1));
        assertEq(account.lastActionTimestamp(), time);

        // And: the exposure of the Creditors is updated.
        (actualExposure,,,) = erc20AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
        (actualExposure,,,) = erc20AM.riskParams(address(creditorStable1), assetKey);
        assertEq(actualExposure, exposure);
    }

    function testFuzz_Success_openMarginAccount_DifferentNumeraire(
        address liquidator,
        uint96 minimumMargin,
        uint32 time
    ) public {
        // Confirm initial numeraire is not set for the Account
        assertEq(account.numeraire(), address(0));

        // Update numeraire of the creditor to TOKEN1
        creditorStable1.setNumeraire(address(mockERC20.token1));
        // Update liquidation costs in creditor
        creditorStable1.setMinimumMargin(minimumMargin);
        // Update liquidator in creditor
        creditorStable1.setLiquidator(liquidator);

        vm.warp(time);

        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit AccountV3.NumeraireSet(address(mockERC20.token1));
        vm.expectEmit();
        emit AccountV3.MarginAccountChanged(address(creditorStable1), liquidator);
        account.openMarginAccount(address(creditorStable1));
        vm.stopPrank();

        assertEq(account.creditor(), address(creditorStable1));
        assertEq(account.liquidator(), liquidator);
        assertEq(account.numeraire(), address(mockERC20.token1));
        assertEq(account.minimumMargin(), minimumMargin);
        assertEq(account.lastActionTimestamp(), time);
    }

    function testFuzz_Success_openMarginAccount_SameNumeraire(uint32 time) public {
        // Deploy an Account with numeraire set to STABLE1
        address deployedAccount = factory.createAccount(1111, 0, address(0));
        AccountV3(deployedAccount).setNumeraire(address(mockERC20.stable1));
        assertEq(AccountV3(deployedAccount).numeraire(), address(mockERC20.stable1));
        assertEq(creditorStable1.numeraire(), address(mockERC20.stable1));

        vm.warp(time);

        vm.expectEmit();
        emit AccountV3.MarginAccountChanged(address(creditorStable1), Constants.initLiquidator);
        AccountV3(deployedAccount).openMarginAccount(address(creditorStable1));

        assertEq(AccountV3(deployedAccount).liquidator(), Constants.initLiquidator);
        assertEq(AccountV3(deployedAccount).creditor(), address(creditorStable1));
        assertEq(AccountV3(deployedAccount).numeraire(), address(mockERC20.stable1));
        assertEq(AccountV3(deployedAccount).minimumMargin(), Constants.initLiquidationCost);
        assertEq(AccountV3(deployedAccount).lastActionTimestamp(), time);
    }
}
