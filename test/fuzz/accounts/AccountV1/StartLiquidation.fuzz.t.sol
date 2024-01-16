/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";
import { ICreditor } from "../../../../src/interfaces/ICreditor.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { AssetValuationLibExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "startLiquidation" of contract "AccountV1".
 */
contract startLiquidation_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountExtension2;
    AssetValuationLibExtension internal assetValuationLib;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        vm.prank(users.accountOwner);
        accountExtension2 = new AccountExtension(address(factory));

        assetValuationLib = new AssetValuationLibExtension();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_startLiquidation_Reentered(address liquidationInitiator) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(accountExtension.liquidator());
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.startLiquidation(liquidationInitiator);
        vm.stopPrank();
    }

    function testFuzz_Revert_startLiquidation_notLiquidatable_usedMarginSmallerThanLiquidationValue(
        uint96 minimumMargin,
        uint256 openDebt,
        uint112 depositAmountToken1,
        address liquidationInitiator
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        depositAmountToken1 = uint112(bound(depositAmountToken1, 1, type(uint112).max - 1));

        // Given: openDebt > 0
        openDebt = bound(openDebt, 1, type(uint112).max - minimumMargin);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmountToken1;

        // Initialize Account and set open position on creditor
        accountExtension2.initialize(users.accountOwner, address(registryExtension), address(creditorToken1));
        accountExtension2.setMinimumMargin(minimumMargin);
        creditorToken1.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        AssetValueAndRiskFactors[] memory assetAndRiskValues = registryExtension.getValuesInNumeraire(
            accountExtension2.numeraire(), accountExtension2.creditor(), assetAddresses, assetIds, assetAmounts
        );

        // Given : Liquidation value is greater than or equal to used margin
        vm.assume(openDebt + minimumMargin <= assetValuationLib.calculateLiquidationValue(assetAndRiskValues));

        // Mint and approve token1 tokens
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.token1.mint(users.accountOwner, depositAmountToken1);
        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(accountExtension2), type(uint256).max);

        // Deposit stable1 token in account
        accountExtension2.deposit(assetAddresses, assetIds, assetAmounts);

        // Then : Account should not be liquidatable as openDebt > 0 and liquidationValue > usedMargin
        vm.startPrank(accountExtension2.liquidator());
        vm.expectRevert(AccountErrors.AccountNotLiquidatable.selector);
        accountExtension2.startLiquidation(liquidationInitiator);
        vm.stopPrank();
    }

    function testFuzz_Revert_startLiquidation_notLiquidatable_zeroOpenDebt(
        uint96 minimumMargin,
        address liquidationInitiator
    ) public {
        // Given : openDebt = 0
        uint256 openDebt = 0;

        // Initialize Account and set open position on creditor
        accountExtension2.initialize(users.accountOwner, address(registryExtension), address(creditorToken1));
        accountExtension2.setMinimumMargin(minimumMargin);
        creditorToken1.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        // Assert openDebt of Account == 0
        assert(creditorToken1.getOpenPosition(address(accountExtension2)) == 0);

        // Then : Account should not be liquidatable as openDebt == 0
        vm.startPrank(accountExtension2.liquidator());
        vm.expectRevert(AccountErrors.AccountNotLiquidatable.selector);
        accountExtension2.startLiquidation(liquidationInitiator);
        vm.stopPrank();
    }

    function testFuzz_Success_startLiquidation(
        uint96 minimumMargin,
        uint256 openDebt,
        uint112 depositAmountToken1,
        address liquidationInitiator,
        uint32 time
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        depositAmountToken1 = uint112(bound(depositAmountToken1, 1, type(uint112).max - 1));

        // Given: openDebt > 0
        openDebt = bound(openDebt, 1, type(uint112).max - minimumMargin);

        AssetValueAndRiskFactors[] memory assetAndRiskValues;
        {
            address[] memory assetAddresses = new address[](1);
            assetAddresses[0] = address(mockERC20.token1);

            uint256[] memory assetIds = new uint256[](1);
            assetIds[0] = 0;

            uint256[] memory assetAmounts = new uint256[](1);
            assetAmounts[0] = depositAmountToken1;

            // Given: Account is initialized and an open position is set on creditor
            accountExtension2.initialize(users.accountOwner, address(registryExtension), address(creditorToken1));
            accountExtension2.setMinimumMargin(minimumMargin);
            creditorToken1.setOpenPosition(address(accountExtension2), openDebt);
            stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
                .checked_write(true);

            assetAndRiskValues = registryExtension.getValuesInNumeraire(
                accountExtension2.numeraire(), accountExtension2.creditor(), assetAddresses, assetIds, assetAmounts
            );

            // Given : Liquidation value is smaller than used margin
            vm.assume(openDebt + minimumMargin > assetValuationLib.calculateLiquidationValue(assetAndRiskValues));

            // Mint and approve stable1 tokens
            vm.prank(users.tokenCreatorAddress);
            mockERC20.token1.mint(users.accountOwner, depositAmountToken1);
            vm.startPrank(users.accountOwner);
            mockERC20.token1.approve(address(accountExtension2), type(uint256).max);

            // Deposit stable1 token in account
            accountExtension2.deposit(assetAddresses, assetIds, assetAmounts);
            vm.stopPrank();
        }

        // Warp time
        time = uint32(bound(time, 2 days, type(uint32).max));
        vm.warp(time);
        // Update updatedAt to avoid InactiveOracle() reverts.
        vm.prank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd));

        // When: The liquidator initiates a liquidation
        vm.startPrank(accountExtension2.liquidator());
        (
            address[] memory assetAddresses_,
            uint256[] memory assetIds_,
            uint256[] memory assetAmounts_,
            address creditor_,
            uint96 minimumMargin_,
            uint256 totalOpenDebt,
            AssetValueAndRiskFactors[] memory assetAndRiskValues_
        ) = accountExtension2.startLiquidation(liquidationInitiator);
        vm.stopPrank();

        // Then: Account should be liquidatable and return specific values.
        assertEq(accountExtension2.inAuction(), true);
        assertEq(assetAddresses_[0], address(mockERC20.token1));
        assertEq(assetIds_[0], 0);
        assertEq(assetAmounts_[0], mockERC20.token1.balanceOf(address(accountExtension2)));
        assertEq(creditor_, accountExtension2.creditor());
        assertEq(minimumMargin_, minimumMargin);
        assertEq(totalOpenDebt, ICreditor(accountExtension2.creditor()).getOpenPosition(address(accountExtension2)));
        assertEq(assetAndRiskValues_[0].assetValue, assetAndRiskValues[0].assetValue);
        assertEq(assetAndRiskValues_[0].collateralFactor, assetAndRiskValues[0].collateralFactor);
        assertEq(assetAndRiskValues_[0].liquidationFactor, assetAndRiskValues[0].liquidationFactor);

        // And: lastActionTimestamp is updated.
        assertEq(accountExtension2.lastActionTimestamp(), time);
    }
}
