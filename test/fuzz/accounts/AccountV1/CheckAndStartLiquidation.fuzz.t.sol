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

    function testFuzz_Revert_checkAndStartLiquidation_Reentered() public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.checkAndStartLiquidation();
        vm.stopPrank();
    }

    function testFuzz_Revert_checkAndStartLiquidation_notLiquidatable_usedMarginSmallerThanLiquidationValue(
        uint96 fixedLiquidationCost,
        uint256 openDebt,
        uint128 depositAmountToken1
    ) public {
        // "exposure" is strictly smaller as "maxExposure".
        depositAmountToken1 = uint128(bound(depositAmountToken1, 1, type(uint128).max - 1));

        // Given: openDebt > 0
        openDebt = bound(openDebt, 1, type(uint128).max - fixedLiquidationCost);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmountToken1;

        // Initialize Account and set open position on trusted creditor
        accountExtension2.initialize(
            users.accountOwner, address(mainRegistryExtension), address(mockERC20.token1), address(creditorToken1)
        );
        accountExtension2.setFixedLiquidationCost(fixedLiquidationCost);
        creditorToken1.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        RiskModule.AssetValueAndRiskFactors[] memory assetAndRiskValues = mainRegistryExtension.getValuesInBaseCurrency(
            accountExtension2.baseCurrency(),
            accountExtension2.trustedCreditor(),
            assetAddresses,
            assetIds,
            assetAmounts
        );

        // Given : Liquidation value is greater than or equal to used margin
        vm.assume(openDebt + fixedLiquidationCost <= RiskModule.calculateLiquidationValue(assetAndRiskValues));

        // Mint and approve token1 tokens
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.token1.mint(users.accountOwner, depositAmountToken1);
        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(accountExtension2), type(uint256).max);

        // Deposit stable1 token in account
        accountExtension2.deposit(assetAddresses, assetIds, assetAmounts);

        // Then : Account should not be liquidatable as openDebt > 0 and liquidationValue > usedMargin
        vm.startPrank(accountExtension2.liquidator());
        vm.expectRevert("A_CASL: Account not liquidatable");
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
            users.accountOwner, address(mainRegistryExtension), address(mockERC20.token1), address(creditorToken1)
        );
        accountExtension2.setFixedLiquidationCost(fixedLiquidationCost);
        creditorToken1.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        // Assert openDebt of Account == 0
        assert(creditorToken1.getOpenPosition(address(accountExtension2)) == 0);

        // Then : Account should not be liquidatable as openDebt == 0
        vm.startPrank(accountExtension2.liquidator());
        vm.expectRevert("A_CASL: Account not liquidatable");
        accountExtension2.checkAndStartLiquidation();
        vm.stopPrank();
    }

    function testFuzz_Success_checkAndStartLiquidation(
        uint96 fixedLiquidationCost,
        uint256 openDebt,
        uint128 depositAmountToken1
    ) public {
        // "exposure" is strictly smaller as "maxExposure".
        depositAmountToken1 = uint128(bound(depositAmountToken1, 1, type(uint128).max - 1));

        // Given: openDebt > 0
        openDebt = bound(openDebt, 1, type(uint128).max - fixedLiquidationCost);

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = address(mockERC20.token1);

        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = 0;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = depositAmountToken1;

        // Given: Account is initialized and an open position is set on trusted creditor
        accountExtension2.initialize(
            users.accountOwner, address(mainRegistryExtension), address(mockERC20.token1), address(creditorToken1)
        );
        accountExtension2.setFixedLiquidationCost(fixedLiquidationCost);
        creditorToken1.setOpenPosition(address(accountExtension2), openDebt);
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension2))
            .checked_write(true);

        RiskModule.AssetValueAndRiskFactors[] memory assetAndRiskValues = mainRegistryExtension.getValuesInBaseCurrency(
            accountExtension2.baseCurrency(),
            accountExtension2.trustedCreditor(),
            assetAddresses,
            assetIds,
            assetAmounts
        );

        // Given : Liquidation value is smaller than used margin
        vm.assume(openDebt + fixedLiquidationCost > RiskModule.calculateLiquidationValue(assetAndRiskValues));

        // Mint and approve stable1 tokens
        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.token1.mint(users.accountOwner, depositAmountToken1);
        vm.startPrank(users.accountOwner);
        mockERC20.token1.approve(address(accountExtension2), type(uint256).max);

        // Deposit stable1 token in account
        accountExtension2.deposit(assetAddresses, assetIds, assetAmounts);

        // When : The liquidator initiates a liquidation
        vm.startPrank(accountExtension2.liquidator());
        (
            address[] memory assetAddresses_,
            uint256[] memory assetIds_,
            uint256[] memory assetAmounts_,
            address owner_,
            address creditor_,
            uint256 totalOpenDebt,
            RiskModule.AssetValueAndRiskFactors[] memory assetAndRiskValues_
        ) = accountExtension2.checkAndStartLiquidation();
        vm.stopPrank();

        // Then : Account should be liquidatable and return specific values
        assertEq(owner_, accountExtension2.owner());
        assertEq(assetAddresses_[0], address(mockERC20.token1));
        assertEq(assetIds_[0], 0);
        assertEq(assetAmounts_[0], mockERC20.token1.balanceOf(address(accountExtension2)));
        assertEq(creditor_, accountExtension2.trustedCreditor());
        assertEq(
            totalOpenDebt,
            ITrustedCreditor(accountExtension2.trustedCreditor()).getOpenPosition(address(accountExtension2))
        );
        assertEq(assetAndRiskValues_[0].assetValue, assetAndRiskValues[0].assetValue);
        assertEq(assetAndRiskValues_[0].collateralFactor, assetAndRiskValues[0].collateralFactor);
        assertEq(assetAndRiskValues_[0].liquidationFactor, assetAndRiskValues[0].liquidationFactor);
    }
}