/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";
import { RiskModule } from "../../../../src/RiskModule.sol";
import { IMainRegistry } from "../../../../src/interfaces/IMainRegistry.sol";
import { ITrustedCreditor } from "../../../../src/interfaces/ITrustedCreditor.sol";

/**
 * @notice Fuzz tests for the "checkAndStartLiquidation" of contract "AccountV1".
 */
contract CheckAndStartLiquidation_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountExtension internal accountExtension2;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        vm.prank(users.accountOwner);
        accountExtension2 = new AccountExtension();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_checkAndStartLiquidation_nonLiquidator(address nonLiquidator) public {
        // openMarginAccount() will set a liquidator on the account
        vm.startPrank(users.accountOwner);
        proxyAccount.openTrustedMarginAccount(address(trustedCreditor));

        vm.assume(nonLiquidator != proxyAccount.liquidator());

        vm.startPrank(nonLiquidator);
        vm.expectRevert("A: Only Liquidator");
        proxyAccount.checkAndStartLiquidation();
        vm.stopPrank();
    }

    function testFuzz_Revert_checkAndStartLiquidation_notLiquidatable_usedMarginSmallerThanLiquidationValue(
        uint96 fixedLiquidationCost,
        uint256 openDebt,
        uint128 depositAmountStable1
    ) public {
        vm.assume(depositAmountStable1 > 0);

        // Given: openDebt > 0
        openDebt = bound(openDebt, 1, type(uint256).max - fixedLiquidationCost);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmountStable1;

        // Initialize Account and set open position on trusted creditor
        accountExtension2.initialize(
            users.accountOwner, address(mainRegistryExtension), address(mockERC20.token1), address(trustedCreditor)
        );
        accountExtension2.setFixedLiquidationCost(fixedLiquidationCost);
        trustedCreditor.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        RiskModule.AssetValueAndRiskVariables[] memory assetAndRiskValues = mainRegistryExtension
            .getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, accountExtension2.baseCurrency());

        // Given : Liquidation value is greater than or equal to used margin
        vm.assume(openDebt + fixedLiquidationCost <= RiskModule.calculateLiquidationValue(assetAndRiskValues));

        // Mint and approve Stable1 tokens
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.accountOwner, depositAmountStable1);
        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(accountExtension2), type(uint256).max);

        // Deposit stable1 token in account
        accountExtension2.deposit(assetAddresses, assetIds, assetAmounts);

        // Then : Account should not be liquidatable as openDebt > 0 and liquidationValue > usedMargin
        vm.startPrank(accountExtension2.liquidator());
        vm.expectRevert("A_CASL, Account not liquidatable");
        accountExtension2.checkAndStartLiquidation();
        vm.stopPrank();
    }

    function testFuzz_Revert_checkAndStartLiquidation_notLiquidatable_zeroOpenDebt(uint96 fixedLiquidationCost)
        public
    {
        // Given : openDebt = 0
        uint256 openDebt = 0;

        // Initialize Account and set open position on trusted creditor
        accountExtension2.initialize(
            users.accountOwner, address(mainRegistryExtension), address(mockERC20.token1), address(trustedCreditor)
        );
        accountExtension2.setFixedLiquidationCost(fixedLiquidationCost);
        trustedCreditor.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        assert(trustedCreditor.getOpenPosition(address(accountExtension2)) == 0);

        // Then : Account should not be liquidatable as openDebt == 0
        vm.startPrank(accountExtension2.liquidator());
        vm.expectRevert("A_CASL, Account not liquidatable");
        accountExtension2.checkAndStartLiquidation();
        vm.stopPrank();
    }

    function testFuzz_Success_checkAndStartLiquidation(
        uint96 fixedLiquidationCost,
        uint256 openDebt,
        uint128 depositAmountStable1
    ) public {
        vm.assume(depositAmountStable1 > 0);

        // Given: openDebt > 0
        openDebt = bound(openDebt, 1, type(uint256).max - fixedLiquidationCost);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.stable1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmountStable1;

        // Initialize Account and set open position on trusted creditor
        accountExtension2.initialize(
            users.accountOwner, address(mainRegistryExtension), address(mockERC20.token1), address(trustedCreditor)
        );
        accountExtension2.setFixedLiquidationCost(fixedLiquidationCost);
        trustedCreditor.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        RiskModule.AssetValueAndRiskVariables[] memory assetAndRiskValues = mainRegistryExtension
            .getListOfValuesPerAsset(assetAddresses, assetIds, assetAmounts, accountExtension2.baseCurrency());

        // Given : Liquidation value is smaller than used margin
        vm.assume(openDebt + fixedLiquidationCost > RiskModule.calculateLiquidationValue(assetAndRiskValues));

        // Mint and approve stable1 tokens
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.accountOwner, depositAmountStable1);
        vm.startPrank(users.accountOwner);
        mockERC20.stable1.approve(address(accountExtension2), type(uint256).max);

        // Deposit stable1 token in account
        accountExtension2.deposit(assetAddresses, assetIds, assetAmounts);

        // Then : Account should be liquidatable and return specific values
        vm.startPrank(accountExtension2.liquidator());
        (
            address[] memory assetAddresses_,
            uint256[] memory assetIds_,
            uint256[] memory assetAmounts_,
            address creditor_,
            uint256 totalOpenDebt,
            RiskModule.AssetValueAndRiskVariables[] memory assetAndRiskValues_
        ) = accountExtension2.checkAndStartLiquidation();
        vm.stopPrank();

        assertEq(assetAddresses_[0], address(mockERC20.stable1));
        assertEq(assetIds_[0], 0);
        assertEq(assetAmounts_[0], mockERC20.stable1.balanceOf(address(accountExtension2)));
        assertEq(creditor_, accountExtension2.trustedCreditor());
        assertEq(
            totalOpenDebt,
            ITrustedCreditor(accountExtension2.trustedCreditor()).getOpenPosition(address(accountExtension2))
        );
        assertEq(assetAndRiskValues_[0].valueInBaseCurrency, assetAndRiskValues_[0].valueInBaseCurrency);
        assertEq(assetAndRiskValues_[0].collateralFactor, assetAndRiskValues[0].collateralFactor);
        assertEq(assetAndRiskValues_[0].liquidationFactor, assetAndRiskValues[0].liquidationFactor);
    }
}
