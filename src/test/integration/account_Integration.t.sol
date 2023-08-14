/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";
import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { AccountExtension, AccountV1 } from "../utils/Extensions.sol";

contract Account_Integration_Test is Base_IntegrationAndUnit_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountExtension internal accountExtension;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();

        // Deploy Account.
        accountExtension = new AccountExtension();
        // Set account in factory.
        stdstore.target(address(factory)).sig(factory.isAccount.selector).with_key(address(accountExtension))
            .checked_write(true);
        // Initiate Reentrancy guard.
        accountExtension.setLocked(1);
    }

    /* ///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testRevert_initialize_InvalidMainreg() public {
        vm.expectRevert("V_I: Registry cannot be 0!");
        accountExtension.initialize(users.accountOwner, address(0), address(0), address(0));
    }

    function testRevert_initialize_AlreadyInitialized() public {
        accountExtension.initialize(users.accountOwner, address(mainRegistryExtension), address(0), address(0));

        vm.expectRevert("V_I: Already initialized!");
        accountExtension.initialize(users.accountOwner, address(mainRegistryExtension), address(0), address(0));
    }

    function test_initialize(address owner_) public {
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencySet(address(0));
        accountExtension.initialize(owner_, address(mainRegistryExtension), address(0), address(0));

        assertEq(accountExtension.owner(), owner_);
        assertEq(accountExtension.getLocked(), 1);
        assertEq(accountExtension.registry(), address(mainRegistryExtension));
        assertEq(accountExtension.baseCurrency(), address(0));
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    function test_openTrustedMarginAccount() public {
        // Assert no creditor has been set on deployment
        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(0));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), false);
        // Assert no liquidator, baseCurrency and liquidation costs have been defined on deployment
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), address(0));
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), 0);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(0));

        // Open a margin account
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), true);
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), initBaseCurrency);
    }

    function testRevert_openTrustedMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert("A: Only Owner");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
    }

    function testRevert_openTrustedMarginAccount_AlreadySet() public {
        // Open a margin account => will set a trusted creditor
        vm.startPrank(users.accountOwner);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));

        // Should revert if a trusted creditor is already set
        vm.expectRevert("V_OTMA: ALREADY SET");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
    }

    function testRevert_openTrustedMarginAccount_InvalidAccountVersion() public {
        // set a different Account version on the trusted creditor
        defaultTrustedCreditor.setCallResult(false);
        vm.startPrank(users.accountOwner);
        vm.expectRevert("V_OTMA: Invalid Version");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount((address(defaultTrustedCreditor)));
        vm.stopPrank();
    }

    function testFuzz_openTrustedMarginAccount_DifferentBaseCurrency(address liquidator, uint96 fixedLiquidationCost)
        public
    {
        // Confirm initial base currency is not set for the Account
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(0));

        // Update base currency of the trusted creditor to TOKEN1
        defaultTrustedCreditor.setBaseCurrency(address(mockERC20.token1));
        // Update liquidation costs in trusted creditor
        defaultTrustedCreditor.setFixedLiquidationCost(fixedLiquidationCost);
        // Update liquidator in trusted creditor
        defaultTrustedCreditor.setLiquidator(liquidator);

        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit BaseCurrencySet(address(mockERC20.token1));
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(defaultTrustedCreditor), liquidator);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
        vm.stopPrank();

        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(defaultTrustedCreditor));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), true);
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), liquidator);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(mockERC20.token1));
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), fixedLiquidationCost);
    }

    function test_openTrustedMarginAccount_SameBaseCurrency() public {
        // Deploy a Account with baseCurrency set to STABLE1
        address deployedAccount = factory.createAccount(1111, 0, address(mockERC20.stable1), address(0));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(trustedCreditorWithParamsInit.baseCurrency(), address(mockERC20.stable1));

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        AccountV1(deployedAccount).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));

        assertEq(AccountV1(deployedAccount).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccount).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(AccountV1(deployedAccount).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertTrue(AccountV1(deployedAccount).isTrustedCreditorSet());
    }

    /* ///////////////////////////////////////////////////////////////
                        LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_liquidateAccount_Reentered(uint128 debt) public {
        // Set Reentrancy guard in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotAuthorized(uint128 debt, address unprivilegedAddress) public {
        // msg.sender is different from the Liquidator.
        vm.assume(unprivilegedAddress != accountExtension.liquidator());

        // Should revert if not called by the Liquidator
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("V_LV: Only Liquidator");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_AccountIsHealthy(
        uint128 debt,
        uint128 liquidationValue,
        uint96 fixedLiquidationCost
    ) public {
        // Assume vault is healthy: liquidationValue is bigger than usedMargin (debt + fixedLiquidationCost).
        uint256 usedMargin = uint256(debt) + fixedLiquidationCost;
        vm.assume(liquidationValue >= usedMargin);

        // Initiate Vault (set owner and baseCurrency).
        accountExtension.initialize(
            users.accountOwner,
            address(mainRegistryExtension),
            address(mockERC20.stable1),
            address(trustedCreditorWithParamsInit)
        );

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(fixedLiquidationCost);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, liquidationValue);

        // Should revert if vault is healthy.
        vm.startPrank(accountExtension.liquidator());
        vm.expectRevert("V_LV: liqValue above usedMargin");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_liquidateAccount_Unhealthy(uint128 debt, uint128 liquidationValue, uint96 fixedLiquidationCost)
        public
    {
        // Assume vault is unhealthy: liquidationValue is smaller than usedMargin (debt + fixedLiquidationCost).
        uint256 usedMargin = uint256(debt) + fixedLiquidationCost;
        vm.assume(liquidationValue < usedMargin);

        // Initiate Vault (set owner and baseCurrency).
        accountExtension.initialize(
            users.accountOwner,
            address(mainRegistryExtension),
            address(mockERC20.stable1),
            address(trustedCreditorWithParamsInit)
        );

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(fixedLiquidationCost);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, liquidationValue);

        // Should liquidate the Account.
        vm.startPrank(accountExtension.liquidator());
        vm.expectEmit(true, true, true, true);
        emit TrustedMarginAccountChanged(address(0), address(0));
        (address originalOwner, address baseCurrency, address trustedCreditor_) =
            accountExtension.liquidateAccount(debt);
        vm.stopPrank();

        assertEq(originalOwner, users.accountOwner);
        assertEq(baseCurrency, address(mockERC20.stable1));
        assertEq(trustedCreditor_, address(trustedCreditorWithParamsInit));

        assertEq(accountExtension.owner(), Constants.initLiquidator);
        assertEq(accountExtension.isTrustedCreditorSet(), false);
        assertEq(accountExtension.trustedCreditor(), address(0));
        assertEq(accountExtension.fixedLiquidationCost(), 0);
    }
}
